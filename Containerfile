ARG ANSIBLE_RUNNER_IMAGE=quay.io/ansible/ansible-runner:devel
ARG PYTHON_BUILDER_IMAGE=quay.io/ansible/python-builder:latest

FROM $ANSIBLE_RUNNER_IMAGE as galaxy

ARG ANSIBLE_GALAXY_CLI_COLLECTION_OPTS=
ADD _build /build

WORKDIR /build
RUN ansible-galaxy role install -r requirements.yml --roles-path /usr/share/ansible/roles
RUN ansible-galaxy collection install $ANSIBLE_GALAXY_CLI_COLLECTION_OPTS -r requirements.yml --collections-path /usr/share/ansible/collections

FROM $PYTHON_BUILDER_IMAGE as builder
ADD _build/requirements_combined.txt /tmp/src/requirements.txt
ADD _build/bindep_combined.txt /tmp/src/bindep.txt
RUN assemble

FROM $ANSIBLE_RUNNER_IMAGE

COPY --from=galaxy /usr/share/ansible /usr/share/ansible

COPY --from=builder /output/ /output/
RUN yum install -y yum-utils && \
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo && \
    yum -y install terraform 

RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
RUN curl -L -O https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz && \
  tar -xvf oc.tar.gz && \
  mv oc /usr/local/bin && \
  rm oc.tar.gz
  
RUN /output/install-from-bindep && rm -rf /output/wheels
RUN alternatives --set python /usr/bin/python3
COPY --from=quay.io/project-receptor/receptor:0.9.6 /usr/bin/receptor /usr/bin/receptor
RUN mkdir -p /var/run/receptor
ADD run.sh /run.sh
CMD /run.sh
USER 1000
