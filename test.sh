#!/bin/bash

terraform apply -no-color -var "min_size=1" -var "max_size=2" -input=false -refresh=true > first_output.log

sync

terraform apply -no-color -var "min_size=2" -var "max_size=4" -input=false -refresh=true > second_output.log

sync