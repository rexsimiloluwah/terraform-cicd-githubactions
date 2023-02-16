#!/bin/bash                                                                 

aws s3api create-bucket \
    --bucket $1 \
    --region us-west-2 \
    --create-bucket-configuration '{
        "LocationConstraint":"us-west-2"
    }' \
    --profile ademola
