FROM ubuntu:xenial as app
LABEL maintainer="devops@knotta.ru"

# Packages installed:
# git
#     Used to pull in particular requirements from github rather than pypi,
#     and to check the sha of the code checkout.
# language-pack-en locales
#     ubuntu locale support so that system utilities have a consistent
#     language and time zone.
# python3.5
#     ubuntu doesnt ship with python, so this is the python we will use to run the
#     application
# python3-pip
#     install pip to install application requirements.txt files
# libssl-dev
#     mysqlclient wont install without this.
# libmysqlclient-dev
#     to install header files needed to use native C implementation for
#     MySQL-python for performance gains.

# If you add a package here please include a comment above describing what it is used for
RUN apt-get update && \
apt-get install -y software-properties-common && \
apt-add-repository -y ppa:deadsnakes/ppa && apt-get update && \
apt-get upgrade -qy && apt-get install language-pack-en locales git \
libmysqlclient-dev libssl-dev build-essential python3.8-dev python3.8-venv -qy && \
rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/venv
RUN python3.8 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip install pip==20.2.3 setuptools==50.3.0

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Prod ports
EXPOSE 8160
EXPOSE 8161

RUN useradd -m --shell /bin/false app

WORKDIR /edx/app/enterprise_catalog/enterprise_catalog

COPY requirements/ /edx/app/enterprise_catalog/enterprise_catalog/requirements/
RUN pip install -r /edx/app/enterprise_catalog/enterprise_catalog/requirements/production.txt

# Code is owned by root so it cannot be modified by the application user.
# So we copy it before changing users.
USER app

# Gunicorn 19 does not log to stdout or stderr by default. Once we are past gunicorn 19, the logging to STDOUT need not be specified.
CMD ["gunicorn", "--workers=2", "--name", "enterprise_catalog", "-c", "/edx/app/enterprise_catalog/enterprise_catalog/enterprise_catalog/docker_gunicorn_configuration.py", "--log-file", "-", "--max-requests=1000", "enterprise_catalog.wsgi:application"]

# This line is after the requirements so that changes to the code will not
# bust the image cache
COPY . /edx/app/enterprise_catalog/enterprise_catalog

FROM app as newrelic
RUN pip install newrelic
CMD ["newrelic-admin", "run-program", "gunicorn", "--workers=2", "--name", "enterprise_catalog", "-c", "/edx/app/enterprise_catalog/enterprise_catalog/enterprise_catalog/docker_gunicorn_configuration.py", "--log-file", "-", "--max-requests=1000", "enterprise_catalog.wsgi:application"]

# Creating image used by devstack
FROM app as legacy_devapp
# Dev ports
EXPOSE 18160
EXPOSE 18161
USER root
RUN pip install -r /edx/app/enterprise_catalog/enterprise_catalog/requirements/dev.txt
USER app
CMD ["gunicorn", "--reload", "--workers=2", "--name", "enterprise_catalog", "-b", ":18160", "-c", "/edx/app/enterprise_catalog/enterprise_catalog/enterprise_catalog/docker_gunicorn_configuration.py", "--log-file", "-", "--max-requests=1000", "enterprise_catalog.wsgi:application"]
