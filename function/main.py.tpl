import functions_framework
from google.cloud import bigquery
import os
from googleapiclient import discovery
from datetime import datetime, timedelta
from googleapiclient import discovery, errors
import pytz
import json

def create_daily_avg_budget(project : str = ""):
    data_project_id = "${billing_data_export_project_id}"
    billing_account_id = "${billing_account_id}"  
    channel_full_names = "${channel_full_names}"
    channel_full_names = channel_full_names.strip().split(",")
    for channel in channel_full_names:
        print(channel)

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

    try:
        query_job = client.query(query)  # API request

        # Wait for the query to finish
        results = query_job.result()
    except Exception as e:
        print(f"Failed to execute query: {e}")
        return

    if project:
        # Print results
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
        service = discovery.build('billingbudgets', 'v1')
    except errors.HttpError as e:
        print(f"Failed to build the service object: {e}")
        return
    display_year = str(start_date_jerusalem.year)
    display_month = str(start_date_jerusalem.month)
    display_day = str(start_date_jerusalem.day)

    display_name = ""
    budget_filter = {}
    if project:
        display_name = f"Daily-Average-Budget-{project}-{display_year}-{display_month}-{display_day}"
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
        display_name = f"Daily-Average-Budget-{display_year}-{display_month}-{display_day}"
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
        "displayName": display_name,
        "amount": {
                "specifiedAmount": {
                    "currencyCode": "USD",
                    "units": str(int(average_daily_cost)),
                    "nanos": int((average_daily_cost - int(average_daily_cost)) * 1e9)
            }
        },
        "thresholdRules": [
                {"thresholdPercent": .50},
                {"thresholdPercent": 1},
                {"thresholdPercent": 1.50},
        ],
        "notificationsRule": {
            "monitoringNotificationChannels": channel_full_names
        },
        "budgetFilter": budget_filter
    }

    print(budget_body)

    # Make the API request to create the budget
    try:
        request = service.billingAccounts().budgets().create(parent=f'billingAccounts/{billing_account_id}', body=budget_body)
        response = request.execute()
    except errors.HttpError as e:
        print(f"Failed to create the budget: {e}")
        return

    print(response)

    three_days_ago = today_jerusalem - timedelta(days=3)

    # Make the API request to list the budget
    try:
        list_request = service.billingAccounts().budgets().list(parent=f'billingAccounts/{billing_account_id}')
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
                        endDate = budget['budgetFilter']['customPeriod']['endDate']
                        if endDate['year'] == three_days_ago.year and endDate['month'] == three_days_ago.month and endDate['day'] == three_days_ago.day:
                            if budget['displayName'] == f"Daily-Average-Budget-{project}-{start_year}-{start_month}-{start_day}" or budget['displayName'] == f"Daily-Average-Budget-{start_year}-{start_month}-{start_day}":
                                tmp_name = budget['displayName']
                                delete_request = service.billingAccounts().budgets().delete(name=budget['name'])
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
    billing_account_services = "${billing_account_services}"
    billing_account_services = billing_account_services.strip().split(",")
    print(billing_account_services)

    if "${GENERAL_BILLING_ACCOUNT_ALERTS}" == "ON":
        create_daily_avg_budget()
    try:
        for project in budget_projects:
            # Attempt to create the daily average budget
            create_daily_avg_budget(project.strip())
        # Return a success message if the function completes without errors
        return "Budget process completed successfully.", 200
    except Exception as e:
        # Log the error and return an error message
        print(f"An error occurred: {e}")
        # Return a more specific error message or status code as needed
        return f"An error occurred: {e}", 500