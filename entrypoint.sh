#!/bin/ash
set -ex

DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

PSQL_TRUST_LOCALNET=${PSQL_TRUST_LOCALNET:-false}

USERMAP_ORIG_UID=$(id -u ${PG_USER})
USERMAP_ORIG_GID=$(id -g ${PG_USER})
USERMAP_GID=${USERMAP_GID:-${USERMAP_UID:-$USERMAP_ORIG_GID}}
USERMAP_UID=${USERMAP_UID:-$USERMAP_ORIG_UID}
if [[ ${USERMAP_UID} != ${USERMAP_ORIG_UID} ]] || [[ ${USERMAP_GID} != ${USERMAP_ORIG_GID} ]]; then
  echo "Adapting uid and gid for ${PG_USER}:${PG_USER} to $USERMAP_UID:$USERMAP_GID"
  su -c "sed -i -e \"s/:${USERMAP_ORIG_GID}:/:${USERMAP_GID}:/\" /etc/group"
  su -c "sed -i -e \"s/:${USERMAP_ORIG_UID}:${USERMAP_GID}:/:${USERMAP_UID}:${USERMAP_GID}:/\" /etc/passwd"
fi

# listen on all interfaces
cat >> ${PG_CONFDIR}/postgresql <<EOF
listen_addresses = '*'
EOF

if [ "${PSQL_TRUST_LOCALNET}" == "true" ]; then
  echo "Enabling trust samenet in pg_hba.conf..."
  cat >> ${PG_CONFDIR}/pg_hba.conf <<EOF
host    all             all             samenet                 trust
EOF
fi

# allow remote connections to postgresql database
cat >> ${PG_CONFDIR}/pg_hba.conf <<EOF
host    all             all             0.0.0.0/0               md5
EOF

cd ${PG_HOME}

# initialize PostgreSQL data directory
if [ ! -d ${PG_DATADIR} ]; then

  if [ ! -f "${PG_HOME}/pwfile" ]; then
    PG_PASSWORD=$(pwgen -c -n -1 14)
    echo "${PG_PASSWORD}" > ${PG_HOME}/pwfile
  fi

  echo "Initializing database..."
  initdb \
    --pgdata="${PG_DATADIR}" --pwfile=${PG_HOME}/pwfile \
    --username=postgres --encoding=unicode --auth=trust >/dev/null
fi

if [ -f ${PG_HOME}/pwfile ]; then
  PG_PASSWORD=$(cat ${PG_HOME}/pwfile)
  echo "|------------------------------------------------------------------|"
  echo "| PostgreSQL User: postgres, Password: ${PG_PASSWORD}              |"
  echo "|                                                                  |"
  echo "| To remove the PostgreSQL login credentials from the logs, please |"
  echo "| make a note of password and then delete the file pwfile          |"
  echo "| from the data store.                                             |"
  echo "|------------------------------------------------------------------|"
fi

if [ -n "${DB_USER}" ]; then
  if [ -z "${DB_PASS}" ]; then
    echo ""
    echo "WARNING: "
    echo "  Please specify a password for \"${DB_USER}\". Skipping user creation..."
    echo ""
    DB_USER=
  else
    echo "Creating user \"${DB_USER}\"..."
    echo "CREATE ROLE \"${DB_USER}\" with LOGIN CREATEDB PASSWORD '${DB_PASS}';" |
      postgres --single \
        -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql >/dev/null
  fi
fi

if [ -n "${DB_NAME}" ]; then
  echo "Creating database \"${DB_NAME}\"..."
  echo "CREATE DATABASE \"${DB_NAME}\";" | \
    postgres --single \
      -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql >/dev/null

  if [ -n "${DB_USER}" ]; then
    echo "Granting access to database \"${DB_NAME}\" for user \"${DB_USER}\"..."
    echo "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" to \"${DB_USER}\";" |
      postgres --single \
        -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql >/dev/null
  fi
fi

echo "Starting PostgreSQL server..."
exec postgres \
  -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql