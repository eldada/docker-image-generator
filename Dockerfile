FROM docker:dind

# Install needed packages
RUN apk add --update curl openssl bash

# Copy run scripts
COPY run*.sh /
RUN chmod +x /*.sh

ENTRYPOINT ["/bin/bash", "-c", "/run.sh"]
