#!/bin/bash
az login --service-principal -u "591d345d-ce5d-4368-8442-07fbb9d93e26" -p "040b8146-3663-44ba-b6c7-cc724495f977" -t "72f988bf-86f1-41af-91ab-2d7cd011db47" > ~/a.txt
az aks get-credentials --resource-group testaks --name aks101cluster > ~/a.txt
