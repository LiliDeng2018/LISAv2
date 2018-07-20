# Project Deployment/Release plan

## Objective and steps

This document describe about branch management and its release procedure to Jenkins server. Release request can be made by time or feature base.

LISav2 master branch will merge the changes from feature branches. Based on standard practice of code integration, festure branches will be merged to master via PR review process. Up on request of release schedule, it will have a new tag in master branch, and we will run full validation against the specific tag. After passing all release readiness requirement, the code will deploy to Jenkins server.

![alt text](https://github.com/LIS/LISAv2/blob/juhlee/release_model_doc/Documents/LISAv2ReleaseDiagram.jpg)

## Support Contact

Contact LisaSupport@microsoft.com (Linux Integration Service Support), if you have technical issues.
