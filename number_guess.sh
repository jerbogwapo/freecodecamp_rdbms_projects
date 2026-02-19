#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=number_game --no-align --tuples-only"

SECRET_NUMBER=$(( RANDOM % 1000 + 1 ))
NUMBER_OF_GUESSES=0

# Helper to run prepared statements via stdin
run_prepared() {
  echo "$1" | $PSQL
}

# Get username
echo "Enter your username:"
read USERNAME

# Check if user exists (prepared statement)
USER_DATA=$(run_prepared "
  PREPARE get_user(VARCHAR) AS
    SELECT games_played, best_game FROM users WHERE username = \$1;
  EXECUTE get_user('$USERNAME');
  DEALLOCATE get_user;
")

if [[ -z $USER_DATA ]]; then
  # New user (prepared statement)
  run_prepared "
    PREPARE insert_user(VARCHAR) AS
      INSERT INTO users (username) VALUES (\$1);
    EXECUTE insert_user('$USERNAME');
    DEALLOCATE insert_user;
  " > /dev/null
  echo "Welcome, $USERNAME! It looks like this is your first time here."
else
  # Returning user
  GAMES_PLAYED=$(echo $USER_DATA | cut -d'|' -f1)
  BEST_GAME=$(echo $USER_DATA | cut -d'|' -f2)
  echo "Welcome back, $USERNAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
fi

# Guessing loop
echo "Guess the secret number between 1 and 1000:"

while true; do
  read GUESS

  # Validate integer
  if ! [[ $GUESS =~ ^[0-9]+$ ]]; then
    echo "That is not an integer, guess again:"
    continue
  fi

  (( NUMBER_OF_GUESSES++ ))

  if [[ $GUESS -eq $SECRET_NUMBER ]]; then
    echo "You guessed it in $NUMBER_OF_GUESSES tries. The secret number was $SECRET_NUMBER. Nice job!"

    # Update games_played (prepared statement)
    run_prepared "
      PREPARE update_games(VARCHAR) AS
        UPDATE users SET games_played = games_played + 1 WHERE username = \$1;
      EXECUTE update_games('$USERNAME');
      DEALLOCATE update_games;
    " > /dev/null

    # Update best_game if better or first win (prepared statement)
    run_prepared "
      PREPARE update_best(INT, VARCHAR) AS
        UPDATE users SET best_game = \$1 WHERE username = \$2 AND (best_game IS NULL OR \$1 < best_game);
      EXECUTE update_best($NUMBER_OF_GUESSES, '$USERNAME');
      DEALLOCATE update_best;
    " > /dev/null

    break

  elif [[ $GUESS -gt $SECRET_NUMBER ]]; then
    echo "It's lower than that, guess again:"
  else
    echo "It's higher than that, guess again:"
  fi
done