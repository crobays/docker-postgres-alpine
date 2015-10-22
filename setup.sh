#!/bin/ash
set -ex

# set this env variable to true to enable a line in the
# pg_hba.conf file to trust samenet.  this can be used to connect
# from other containers on the same host without authentication

# fix permissions and ownership
mkdir -p ${PG_USER} && chown -R postgres:postgres ${PG_USER}
mkdir -p -m 0700 ${PG_HOME} && chown -R postgres:postgres ${PG_HOME}
mkdir -p -m 0755 ${PG_RUNDIR} && chown -R postgres:postgres ${PG_RUNDIR} && chmod g+s ${PG_RUNDIR}
mkdir -p ${PG_LOGDIR} && chown -R postgres:postgres ${PG_LOGDIR}

# disable ssl
sed 's/ssl = true/#ssl = true/' -i ${PG_CONFDIR}/postgresql.conf

chown -R postgres:postgres ${PG_CONFDIR}
