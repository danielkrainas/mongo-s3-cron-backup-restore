FROM mongo

RUN apt-get update && apt-get install -y cron curl python-pip
RUN pip install awscli

ADD entrypoint.sh /
ENTRYPOINT ./entrypoint.sh
