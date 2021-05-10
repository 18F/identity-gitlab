# Dashboard

This sets up https://github.com/kubernetes/dashboard .

To access it, do this:
```
kubectl port-forward service/dashboard-kubernetes-dashboard 4430:443 -n kubernetes-dashboard
```
and then go to http://localhost:4430/
