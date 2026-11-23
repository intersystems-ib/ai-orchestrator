ARG IMAGE=intersystems/iris-community:2027.1.0AI.109.0
FROM ${IMAGE}

USER root
WORKDIR /opt/irisapp
RUN chown -R ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp

USER ${ISC_PACKAGE_MGRUSER}

COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris-demo/src/ ./src/
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris-demo/iris.cpf /tmp/iris.cpf
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris-demo/iris.script ./iris.script

ENV ISC_CPF_MERGE_FILE=/tmp/iris.cpf

RUN iris start IRIS \
    && iris session IRIS < /opt/irisapp/iris.script \
    && iris stop IRIS quietly

