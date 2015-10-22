FROM alpine:3.2

MAINTAINER crobays@userex.nl

RUN apk add --update \
    postgresql \
    pwgen


ENV PG_VERSION=9.4 \
    PG_USER=postgres \
    USERMAP_GID=501 \
    PG_HOME=/var/lib/postgresql \
    PG_RUNDIR=/var/run/postgresql \
    PG_LOGDIR=/var/log/postgresql
    
ENV PG_CONFDIR="/etc/postgresql/${PG_VERSION}/main" \
    PG_DATADIR="${PG_HOME}/${PG_VERSION}/main"

ENV DB_NAME=default \
    DB_USER=admin \
    DB_PASS=secret

EXPOSE 5432

ADD postgresql.conf ${PG_CONFDIR}/postgresql.conf

ADD setup.sh /setup.sh
RUN /setup.sh

ADD entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

VOLUME ["/var/lib/postgresql"]
VOLUME ["/run/postgresql"]
USER postgres

CMD ["/entrypoint.sh"]

# docker run -it -p 5432:5432 crobays/postgres-alpine ash