ARG IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.2.0AI.162.0
FROM ${IMAGE}

USER root
WORKDIR /opt/irisapp
RUN chown -R ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp

USER ${ISC_PACKAGE_MGRUSER}

COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris/src/ ./src/
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris/iris.cpf /tmp/iris.cpf
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris/iris.script ./iris.script

ENV ISC_CPF_MERGE_FILE=/tmp/iris.cpf

RUN iris start IRIS \
    && iris session IRIS < /opt/irisapp/iris.script \
    && iris stop IRIS quietly

