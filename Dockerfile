FROM docker:dind

# Copy run scripts
COPY run*.sh /

# Install needed packages and set ex
RUN apk add --update curl openssl bash && \
    chmod +x /*.sh

ENTRYPOINT ["/bin/bash", "-c", "/run.sh"]
