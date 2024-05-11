# identity-fake-server

This sets up https://github.com/18F/identity-fake-server.

To access it, do this:
```
kubectl port-forward service/identity-fake-server 5555:5555 -n identity-fake-server
```
and then go to http://localhost:5555/
