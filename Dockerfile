FROM docker:dind

# Install curl, jq and bash
RUN apk add --update curl openssl bash

# Copy run scripts
COPY *.sh /
RUN chmod +x /*.sh

ENTRYPOINT ["/bin/bash", "-c", "/run.sh"]
