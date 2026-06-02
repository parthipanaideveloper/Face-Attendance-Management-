import os
import requests

def send_sms(phone_number, message):
    """
    Sends an SMS using Fast2SMS API.
    Ensure you have set the FAST2SMS_API_KEY environment variable.
    """
    api_key = os.environ.get("FAST2SMS_API_KEY")
    if not api_key:
        print("[WARNING] Fast2SMS API key not found in environment variables. SMS not sent.")
        return False

    url = "https://www.fast2sms.com/dev/bulkV2"
    
    payload = {
        "route": "v3",
        "sender_id": "TXTIND",
        "message": message,
        "language": "english",
        "flash": 0,
        "numbers": phone_number,
    }

    headers = {
        'authorization': api_key,
        'Content-Type': "application/x-www-form-urlencoded",
        'Cache-Control': "no-cache",
    }

    try:
        response = requests.request("POST", url, data=payload, headers=headers)
        if response.status_code == 200:
            print(f"[SUCCESS] SMS sent to {phone_number}: {message}")
            return True
        else:
            print(f"[ERROR] Failed to send SMS to {phone_number}: {response.text}")
            return False
    except Exception as e:
        print(f"[ERROR] Exception while sending SMS: {e}")
        return False

if __name__ == "__main__":
    # Test the service
    test_number = input("Enter a phone number to test SMS: ")
    test_message = "Test message from Face Attendance System."
    send_sms(test_number, test_message)
