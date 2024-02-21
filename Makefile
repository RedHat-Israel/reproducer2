.PHONY: build
build: check-env-tag
	podman build -t reproducer:$(TAG) .

.PHONY: upload
upload: check-env-tag check-env-server
	podman save localhost/reproducer:$(TAG) > _output/$(TAG).tar
	scp _output/$(TAG).tar core@$(SERVER):

.PHONY: load
load: check-env-tag check-env-server
	ssh core@$(SERVER) "sudo podman load < $(TAG).tar"

.PHONY: build-and-upload-and-load
build-and-upload-and-load: build upload load

.PHONY: deploy
deploy: check-env-tag
	oc new-project reproducer || oc project reproducer
	oc adm policy add-scc-to-user privileged -z default
	oc adm policy add-role-to-user cluster-reader -z default
	bash privileged.sh reproducer
	oc apply -f sriovnetwork.yaml
	oc create configmap --from-file=blue.sh=blue.sh --from-file=red.sh=red.sh entrypoint
	cat blue.yaml | sed 's/TAG/$(TAG)/' | oc apply -f -
	cat red.yaml | sed 's/TAG/$(TAG)/' | oc apply -f -

.PHONY: undeploy
undeploy:
	oc project default
	oc delete project reproducer

.PHONY: check-env-tag
check-env-tag:
ifndef TAG
	$(error TAG is undefined (e.g. test3))
endif

.PHONY: check-env-server
check-env-server:
ifndef SERVER
	$(error SERVER is undefined (e.g. 192.168.18.18))
endif
