#!/bin/bash

PSQL="psql -X --username=freecodecamp --dbname=salon --tuples-only -c"

echo -e "\n~~~~~ Salon Appointment Scheduler ~~~~~\n"

MAIN_MENU() {
  if [[ $1 ]]
  then
    echo -e "\n$1"
  fi

  # Display services BEFORE prompting for input
  SERVICES=$($PSQL "SELECT service_id, name FROM services ORDER BY service_id")
  echo "$SERVICES" | while IFS="|" read SERVICE_ID NAME
  do
    if [[ -n $SERVICE_ID ]]
    then
      # Trim whitespace
      SERVICE_ID_TRIMMED=$(echo $SERVICE_ID | sed 's/^ *| *$//')
      NAME_TRIMMED=$(echo $NAME | sed 's/^ *| *$//')
      echo "$SERVICE_ID_TRIMMED) $NAME_TRIMMED"
    fi
  done

  # NOW prompt for service selection
  read SERVICE_ID_SELECTED
  
  # Validate service_id is a number
  if [[ ! $SERVICE_ID_SELECTED =~ ^[0-9]+$ ]]
  then
    MAIN_MENU "I could not find that service. What would you like today?"
    return
  fi
  
  # Check if service exists using prepared statement
  SERVICE_NAME=$($PSQL "PREPARE check_service AS SELECT name FROM services WHERE service_id = \$1; EXECUTE check_service($SERVICE_ID_SELECTED); DEALLOCATE check_service;")
  
  if [[ -z $SERVICE_NAME ]]
  then
    # Show list again with error message
    MAIN_MENU "I could not find that service. What would you like today?"
  else
    # Get customer phone number
    echo -e "\nWhat's your phone number?"
    read CUSTOMER_PHONE
    
    # Check if customer exists using prepared statement
    CUSTOMER_NAME=$($PSQL "PREPARE check_customer AS SELECT name FROM customers WHERE phone = \$1; EXECUTE check_customer('$CUSTOMER_PHONE'); DEALLOCATE check_customer;")
    
    # If customer doesn't exist, get their name and add them
    if [[ -z $CUSTOMER_NAME ]]
    then
      echo -e "\nI don't have a record for that phone number, what's your name?"
      read CUSTOMER_NAME
      
      # Insert new customer using prepared statement
      INSERT_CUSTOMER_RESULT=$($PSQL "PREPARE insert_customer AS INSERT INTO customers(phone, name) VALUES(\$1, \$2); EXECUTE insert_customer('$CUSTOMER_PHONE', '$CUSTOMER_NAME'); DEALLOCATE insert_customer;")
    fi
    
    # Get customer_id using prepared statement
    CUSTOMER_ID=$($PSQL "PREPARE get_customer_id AS SELECT customer_id FROM customers WHERE phone = \$1; EXECUTE get_customer_id('$CUSTOMER_PHONE'); DEALLOCATE get_customer_id;")
    
    # Get appointment time
    echo -e "\nWhat time would you like your appointment?"
    read SERVICE_TIME
    
    # Insert appointment using prepared statement
    INSERT_APPOINTMENT_RESULT=$($PSQL "PREPARE insert_appointment AS INSERT INTO appointments(customer_id, service_id, time) VALUES(\$1, \$2, \$3); EXECUTE insert_appointment($CUSTOMER_ID, $SERVICE_ID_SELECTED, '$SERVICE_TIME'); DEALLOCATE insert_appointment;")
    
    # Trim whitespace from variables
    SERVICE_NAME=$(echo $SERVICE_NAME | sed 's/^ *| *$//')
    CUSTOMER_NAME=$(echo $CUSTOMER_NAME | sed 's/^ *| *$//')
    
    # Confirmation message
    echo -e "\nI have put you down for a $SERVICE_NAME at $SERVICE_TIME, $CUSTOMER_NAME."
  fi
}

MAIN_MENU