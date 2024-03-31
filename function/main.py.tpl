import functions_framework
from google.cloud import bigquery
import os
from googleapiclient import discovery
from datetime import datetime, timedelta
from googleapiclient import discovery, errors
import pytz
import json

def format_date(year, month, day):
    # Normalize month and day to two digits
    month_normalized = month.zfill(2)
    day_normalized = day.zfill(2)
    
    # Concatenate year, month, and day in the YYYYMMDD format
    formatted_date = f"{year}{month_normalized}{day_normalized}"
    
    return formatted_date

def create_daily_avg_budget(
        project : str = "",
        service_list : list = []):
    data_project_id = "${billing_data_export_project_id}"
    billing_account_id = "${billing_account_id}"  
    channel_full_names = "${channel_full_names}"
    channel_full_names = channel_full_names.strip().split(",")
    for channel in channel_full_names:
        print(channel)

    budget_ceiling = float("${budget_ceiling}")

    print(f"Working with billing account: {billing_account_id}")
    #os.environ["GCLOUD_PROJECT"] = project_id
    #os.environ["GOOGLE_CLOUD_QUOTA_PROJECT"] = project_id

    try:
        client = bigquery.Client(project=data_project_id)
    except Exception as e:
        print(f"Failed to initialize BigQuery client: {e}")
        return


    bq_dataset = "${bigquery_dataset}"
    bq_table = "${bigquery_dataset_table}"

    services_display_name = ""
    if service_list:
        name_string = "("
        for service_name in service_list:
            name_string += f"'{service_name}', "
        name_string = name_string[:-2]
        name_string += ')'

        id_query = f"""
        SELECT DISTINCT service.id, service.description
        FROM `{data_project_id}.{bq_dataset}.{bq_table}`
        WHERE service.description IN {name_string}
        """
        print(f"id_query: {id_query}")

        try:
            id_query_job = client.query(id_query)  # API request

            # Wait for the query to finish
            id_results = id_query_job.result()
            service_ids = {}
            service_name_list = []
            service_fq_name_list = []
            for row in id_results:
                service_fq_name_list.append(f"services/{row.id}")
                service_name_list.append(row.description)
                service_ids[row.description] = row.id
            services_display_name = '-'.join(service_name_list)
            services_display_name = services_display_name.replace('Compute', 'Comp')
            services_display_name = services_display_name.replace('Engine', 'Eng')
            services_display_name = services_display_name.replace(' ', '')
            if not service_name_list:
                services_display_name = ", ".join(service_list)
                if project:
                    print(f"The service(s) {services_display_name} have not been used in project {project}, cannot create this budget.")
                else:
                    print(f"The service(s) {services_display_name} have not been used in billing account {billing_account_id}, cannot create this budget.")
                return

        except Exception as e:
            print(f"Failed to execute id query: {e}")
            return

    query = f"""
    SELECT
    SUM(cost) / COUNT(DISTINCT DATE(usage_start_time)) AS average_daily_cost
    FROM
    `{data_project_id}.{bq_dataset}.{bq_table}`
    WHERE
    usage_start_time >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))
    AND usage_end_time <= CURRENT_TIMESTAMP()
    """

    if project:
        query += f" AND project.id = '{project}'"

    if service_list:
        if len(service_name_list) == 1:
            query_condition = f" AND service.id = '{service_ids[service_list[0]]}'"
        else:
            query_condition = "AND service.id IN ("
            for service_name in service_name_list:
                query_condition += f"'{service_ids[service_name]}', "
            query_condition = query_condition[:-2]
            query_condition += ")"
        query += query_condition
            
    
    print(f"QUERY: {query}")

    try:
        query_job = client.query(query)  # API request

        # Wait for the query to finish
        results = query_job.result()
    except Exception as e:
        print(f"Failed to execute query: {e}")
        return

    if project:
        if service_list:
            if results:
                for row in results:
                    average_daily_cost = row.average_daily_cost
                print(f"Average Daily Cost on project {project} , service(s) {services_display_name}: {row.average_daily_cost}")
            else:
                average_daily_cost = 0.18
                print(f"No spend in past month on project {project} , service(s) {services_display_name}... adding a different value of: {average_daily_cost}")

            if not average_daily_cost:
                average_daily_cost = 0.18
                print(f"No spend in past month on project {project} , service(s) {services_display_name}... adding a different value of: {average_daily_cost}")
        else:
            if results:
                for row in results:
                    average_daily_cost = row.average_daily_cost
                print(f"Average Daily Cost on project {project}: {row.average_daily_cost}")
            else:
                average_daily_cost = 0.18
                print(f"No spend in past month on project {project} ... adding a different value of: {average_daily_cost}")

            if not average_daily_cost:
                average_daily_cost = 0.18
                print(f"No spend in past month on project {project} ... adding a different value of: {average_daily_cost}")
    else:
        if service_list:
            if results:
                for row in results:
                    average_daily_cost = row.average_daily_cost
                print(f"Average Daily Cost on billing account {billing_account_id} , service(s) {services_display_name}: {row.average_daily_cost}")
            else:
                average_daily_cost = 0.18
                print(f"No spend in past month on billing account {billing_account_id} , service(s) {services_display_name} ... adding a different value of: {average_daily_cost}")
            
            if not average_daily_cost:
                average_daily_cost = 0.18
                print(f"No spend in past month on billing account {billing_account_id} , service(s) {services_display_name} ... adding a different value of: {average_daily_cost}")
        else:
            if results:
                for row in results:
                    average_daily_cost = row.average_daily_cost
                print(f"Average Daily Cost on billing account {billing_account_id}: {row.average_daily_cost}")
            else:
                average_daily_cost = 0.18
                print(f"No spend in past month on billing account {billing_account_id} ... adding a different value of: {average_daily_cost}")
            
            if not average_daily_cost:
                average_daily_cost = 0.18
                print(f"No spend in past month on billing account {billing_account_id} ... adding a different value of: {average_daily_cost}")

    # We want the 100% threshold to be triggered at the budget ceiling
    average_daily_cost = average_daily_cost * budget_ceiling

    # Define the timezone for Jerusalem
    jerusalem_tz = pytz.timezone('Asia/Jerusalem')

    # Define the timezone for Jerusalem
    jerusalem_tz = pytz.timezone('Asia/Jerusalem')

    # Get the current date in Jerusalem time
    today_jerusalem = datetime.now(jerusalem_tz).date()
    start_date_jerusalem = today_jerusalem + timedelta(days=1)

    # Calculate the end date to be one day after the start date
    end_date_jerusalem = today_jerusalem + timedelta(days=2)

    # Build the service object for the billing budget API
    try:
        service_obj = discovery.build('billingbudgets', 'v1')
    except errors.HttpError as e:
        print(f"Failed to build the service object: {e}")
        return
    display_year = str(start_date_jerusalem.year)
    display_month = str(start_date_jerusalem.month)
    display_day = str(start_date_jerusalem.day)

    threshold_percentages = "${threshold_percentages}"
    threshold_percentages = threshold_percentages.strip().split(",")
    threshold_rules = []
    for threshold in threshold_percentages:
        threshold_rules.append({"thresholdPercent": float(threshold.strip())})

    display_name = ""
    display_date = format_date(display_year, display_month, display_day)
    budget_filter = {}
    if project:
        if service_list:
            display_name = f"{display_date}-{project}-{services_display_name}"
            budget_filter = {
                "projects": [f"projects/{project}"],
                "services": service_fq_name_list,
                "customPeriod": {
                    "startDate": {
                        "year": start_date_jerusalem.year,
                        "month": start_date_jerusalem.month,
                        "day": start_date_jerusalem.day
                    },
                    "endDate": {
                        "year": end_date_jerusalem.year,
                        "month": end_date_jerusalem.month,
                        "day": end_date_jerusalem.day
                    }
                }
            }
        else:
            display_name = f"{display_date}-{project}"
            budget_filter = {
                "projects": [f"projects/{project}"],
                "customPeriod": {
                    "startDate": {
                        "year": start_date_jerusalem.year,
                        "month": start_date_jerusalem.month,
                        "day": start_date_jerusalem.day
                    },
                    "endDate": {
                        "year": end_date_jerusalem.year,
                        "month": end_date_jerusalem.month,
                        "day": end_date_jerusalem.day
                    }
                }
            }
    else:
        if service_list:
            display_name = f"{display_date}-{services_display_name}"
            budget_filter = {
                "services": service_fq_name_list,
                "customPeriod": {
                    "startDate": {
                        "year": start_date_jerusalem.year,
                        "month": start_date_jerusalem.month,
                        "day": start_date_jerusalem.day
                    },
                    "endDate": {
                        "year": end_date_jerusalem.year,
                        "month": end_date_jerusalem.month,
                        "day": end_date_jerusalem.day
                    }
                }
            }
        else:
            display_name = f"{display_date}"
            budget_filter = {
                "customPeriod": {
                    "startDate": {
                        "year": start_date_jerusalem.year,
                        "month": start_date_jerusalem.month,
                        "day": start_date_jerusalem.day
                    },
                    "endDate": {
                        "year": end_date_jerusalem.year,
                        "month": end_date_jerusalem.month,
                        "day": end_date_jerusalem.day
                    }
                }
            }

    # Construct the budget request body
    budget_body = {
        "displayName": display_name[:60],
        "amount": {
                "specifiedAmount": {
                    "currencyCode": "USD",
                    "units": str(int(average_daily_cost)),
                    "nanos": int((average_daily_cost - int(average_daily_cost)) * 1e9)
            }
        },
        "thresholdRules": [threshold_rules],
        "notificationsRule": {
            "monitoringNotificationChannels": channel_full_names
        },
        "budgetFilter": budget_filter
    }

    print(budget_body)

    # Make the API request to create the budget
    try:
        request = service_obj.billingAccounts().budgets().create(parent=f'billingAccounts/{billing_account_id}', body=budget_body)
        response = request.execute()
    except errors.HttpError as e:
        print(f"Failed to create the budget: {e}")
        return

    print(response)

    two_days_ago = today_jerusalem - timedelta(days=2)

    # Make the API request to list the budget
    try:
        list_request = service_obj.billingAccounts().budgets().list(parent=f'billingAccounts/{billing_account_id}')
        list_response = list_request.execute()
    except errors.HttpError as e:
        print(f"Failed to list budgets: {e}")
        return

    print(list_response)

    try:
        if list_response:
            print(list_response['budgets'])
            for budget in list_response['budgets']:
                if 'budgetFilter' in budget.keys():
                    if 'customPeriod' in budget['budgetFilter'].keys():
                        startDate = budget['budgetFilter']['customPeriod']['startDate']
                        start_year = startDate['year']
                        start_month = startDate['month']
                        start_day = startDate['day']
                        formatted_start_date = format_date(str(start_year), str(start_month), str(start_day))
                        endDate = budget['budgetFilter']['customPeriod']['endDate']
                        if endDate['year'] == two_days_ago.year and endDate['month'] == two_days_ago.month and endDate['day'] == two_days_ago.day:
                            if budget['displayName'] == f"{formatted_start_date}"[:60] or budget['displayName'] == f"{formatted_start_date}-{project}-{services_display_name}"[:60] or budget['displayName'] == f"{formatted_start_date}-{project}"[:60] or budget['displayName'] == f"{formatted_start_date}-{services_display_name}"[:60]:
                                tmp_name = budget['displayName']
                                delete_request = service_obj.billingAccounts().budgets().delete(name=budget['name'])
                                delete_response = delete_request.execute()
                                if delete_response == {}:
                                    print(f"Deleted old budget: {tmp_name}")
                                    break
                                else:
                                    print(delete_response)
        else:
            print("no existing budgets found")
    except errors.HttpError as e:
        print(f"Failed during budget deletion process: {e}")

@functions_framework.http
def main(request):

    budget_projects = "${budget_projects}"
    budget_projects = budget_projects.strip().split(",")
    print(budget_projects)
    services_by_project = json.loads('''${services_by_project}''')
    #Should be same as above
    print(services_by_project.keys())
    billing_account_services = json.loads('''${billing_account_services}''')
    print(f"BILLING ACCOUNT SERVICES: {billing_account_services}")
    
    try:
        if "${GENERAL_BILLING_ACCOUNT_ALERTS}" == "ON":
            create_daily_avg_budget()
        for service_list in billing_account_services:
            create_daily_avg_budget(service_list=service_list)
        # Create budgets on projects without filtering by service
        for project in budget_projects:
            # Attempt to create the daily average budget
            create_daily_avg_budget(project=project.strip())
        # Create budgets on projects with filtering by service
        for project in services_by_project.keys():
            for service_list in services_by_project[project]:
                # Attempt to create the daily average budget
                create_daily_avg_budget(project=project.strip(), service_list=service_list)
        # Return a success message if the function completes without errors
        return "Budget process completed successfully.", 200
    except Exception as e:
        # Log the error and return an error message
        print(f"An error occurred: {e}")
        # Return a more specific error message or status code as needed
        return f"An error occurred: {e}", 500