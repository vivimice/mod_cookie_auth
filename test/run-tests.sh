#!/bin/bash -e
cd "$(dirname $0)"
export SCRIPT_ROOT="$(readlink -f ..)"
export CONFIG_ROOT="$(readlink -f .)"
export SERVER_ROOT=/usr/lib/apache2
export SERVER_PORT=28280
export HTTP_USER=foo
export HTTP_PASSWD=bar
export HTTP_REALM=wonderland
export PASSWD_FILE="${CONFIG_ROOT}/var/passwd"

export VAR_ROOT="${CONFIG_ROOT}/var"
rm -rf "${VAR_ROOT}"
mkdir -p "${VAR_ROOT}" || true

CONFIG_FILE="${CONFIG_ROOT}/var/apache2.conf"
COOKIE_JAR="${CONFIG_ROOT}/var/cookies"

echo "Generating mime types ..."
echo "text/html					html htm shtml" > "${VAR_ROOT}/mime.types"

echo "Generating password file: ${PASSWD_FILE} ..."
printf "%s:%s:%s\n" "${HTTP_USER}" "${HTTP_REALM}" "$(printf "%s:%s:%s" "${HTTP_USER}" "${HTTP_REALM}" "${HTTP_PASSWD}" | md5sum | awk '{print $1}')" > "${PASSWD_FILE}"

echo "Generating configuration file: ${CONFIG_FILE} ..."
envsubst < "${CONFIG_ROOT}/apache2.conf" > "${CONFIG_FILE}"

echo "Starting apache2 at port ${SERVER_PORT} ..."
_cleanExit() {
    kill "${APACHE2_PID}"
    exit 1
}
trap "_cleanExit" EXIT
/usr/sbin/apache2 -D FOREGROUND -d "${SERVER_ROOT}" -f "${CONFIG_FILE}" -X >/dev/null 2>&1 &
APACHE2_PID=$!

echo "Running test cases ..."

if ! curl -vs "http://localhost:${SERVER_PORT}/?case=1" -o /dev/null 2>&1 | grep "HTTP/1.1 401 " >/dev/null; then
    echo "Test [no_auth] failed. should return 401."
    exit 1
fi

if ! curl -vs --digest "http://foo:bar@localhost:${SERVER_PORT}/?case=3" -o /dev/null 2>&1 | grep "HTTP/1.1 200 " >/dev/null; then
    echo "Test [digest_auth] failed. should return 200."
    exit 1
fi

if ! curl -vs "http://localhost:${SERVER_PORT}/?case=3" -o /dev/null 2>&1 | grep "HTTP/1.1 401 " >/dev/null; then
    echo "Test [no_auth_2] failed. should return 401."
    exit 1
fi

if ! curl -vs --digest -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" "http://foo:bar@localhost:${SERVER_PORT}/?case=4" -o /dev/null 2>&1 | grep "HTTP/1.1 200 " >/dev/null; then
    echo "Test [digest_auth_2] failed. should return 200."
    exit 1
fi

if ! curl -vs -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" "http://localhost:${SERVER_PORT}/?case=5" -o /dev/null 2>&1 | grep "HTTP/1.1 200 " >/dev/null; then
    echo "Test [cookie_auth_inst] failed. should return 200."
    exit 1
fi

sleep 1

if ! curl -vs -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" "http://localhost:${SERVER_PORT}/?case=6" -o /dev/null 2>&1 | grep "HTTP/1.1 200 " >/dev/null; then
    echo "Test [cookie_auth_delay_1s] failed. should return 200."
    exit 1
fi

sleep 1

if ! curl -vs -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" "http://localhost:${SERVER_PORT}/?case=7" -o /dev/null 2>&1 | grep "HTTP/1.1 200 " >/dev/null; then
    echo "Test [cookie_auth_delay_1s] failed. should return 200."
    exit 1
fi

sleep 4

if ! curl -vs -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" "http://localhost:${SERVER_PORT}/?case=8" -o /dev/null 2>&1 | grep "HTTP/1.1 401 " >/dev/null; then
    echo "Test [cookie_auth_delay_5s] failed. should return 401."
    exit 1
fi

echo "Test success."
