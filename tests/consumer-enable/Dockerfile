# Consumer path test: a project image that starts from the core image and switches every feature on.
# Built by tests/consumer-enable/check.sh (PR test "test-webcore-enable").
ARG CORE_IMAGE=webcore-core:test
FROM ${CORE_IMAGE}

COPY tests/consumer-enable/webcore.features /etc/webcore/features
RUN webcore-enable --file /etc/webcore/features

# The project's own packages go through the same helper.
RUN webcore-apt jq
