#!/usr/bin/env bash
# ↑ Uses the user's environment to locate bash.
# This is more portable than hardcoding /bin/bash.

set -euo pipefail
# Strict bash mode:
# -e : exit immediately if any command fails
# -u : treat unset variables as errors
# -o pipefail : if any command in a pipeline fails, the pipeline fails

# PORT is taken from the first CLI argument.
# If no argument is provided, default to 8080.
# Example:
#   ./server.sh 9000
# If no value is given:
#   PORT=8080
PORT="${1:-8080}"


# ---------------------------
# Function: html
# ---------------------------
# Returns a static HTML page.
# Uses a HEREDOC to output multi-line HTML.
# The quotes around 'EOF' prevent variable expansion inside the HTML.
html() {
  cat <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Bash Server</title>
</head>
<body>
  <h1>Hello from Bash</h1>
  <p>Your bash HTTP server is working.</p>
</body>
</html>
EOF
}


# ---------------------------
# Function: handle_client
# ---------------------------
# This function processes a single HTTP request.
# It:
# 1. Reads the incoming HTTP request
# 2. Ignores the headers
# 3. Sends a valid HTTP response
handle_client() {

  # HTTP requests look like this:
  #
  # GET / HTTP/1.1
  # Host: localhost:8080
  # User-Agent: ...
  # Accept: ...
  #
  # (blank line)
  #
  # The blank line marks the end of headers.
  #
  # We read lines until we hit that blank line.

  while IFS=$'\r' read -r line; do
    # Stop when the header section ends.
    # Two conditions:
    # - line is just a newline
    # - line is empty after removing carriage returns
    [[ "$line" == $'\n' || -z "${line//$'\r'/}" ]] && break
  done

  # Generate the HTML body using the html() function
  body="$(html)"

  # Calculate the content length.
  # HTTP requires Content-Length for most responses.
  # wc -c counts bytes.
  len=$(printf "%s" "$body" | wc -c)

  # ---------------------------
  # HTTP RESPONSE
  # ---------------------------

  # Status line
  printf 'HTTP/1.1 200 OK\r\n'

  # MIME type header
  printf 'Content-Type: text/html; charset=UTF-8\r\n'

  # Required so the browser knows when the body ends
  printf 'Content-Length: %s\r\n' "$len"

  # Close the connection after response
  printf 'Connection: close\r\n'

  # Blank line separates headers from body
  printf '\r\n'

  # Send the HTML body
  printf '%s' "$body"
}


# Inform the user that the server is running
echo "Serving on http://localhost:${PORT}"


# ---------------------------
# Main server loop
# ---------------------------
# The server runs forever.
# Each iteration:
# 1. Waits for a connection
# 2. Sends the HTTP response
# 3. Closes the connection
while true; do

  # Netcat implementations vary between systems.
  # Linux (GNU netcat) often supports:
  #     nc -l -p PORT
  #
  # BSD/macOS netcat often requires:
  #     nc -l PORT
  #
  # We detect which one is available.

  if nc -h 2>&1 | grep -q -- '-p'; then
    # If netcat supports -p, use Linux-style syntax.

    # handle_client produces the HTTP response.
    # That output is piped into netcat,
    # which sends it to whoever connects.
    handle_client | nc -l -p "$PORT" -q 1

  else
    # BSD/macOS style netcat
    handle_client | nc -l "$PORT"
  fi
done
