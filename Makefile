LOCAL_IMAGE="$(USER)/jupyter-notebook-py3.5"
WAIT_TIME=10

.PHONY: build clean run test

build:
	docker build -t $(LOCAL_IMAGE) .

clean:
	docker rmi -f $(LOCAL_IMAGE)

run:
	docker run -p 8888:8888 -e JUPYTER_NOTEBOOK_PASSWORD=developer -e JUPYTERLAB=false $(USER)/jupyter-notebook-py3.5

test:
	docker run -d --name test-jupyter-notebook -p 8888:8888 -e JUPYTER_NOTEBOOK_PASSWORD=developer -e JUPYTERLAB=false $(USER)/jupyter-notebook-py3.5
	sleep $(WAIT_TIME)
	./ready.sh && echo "Test completed successfully!"
	docker rm -f test-jupyter-notebook
