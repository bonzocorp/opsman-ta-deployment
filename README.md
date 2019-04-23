# opsman-ta-deployment

Travel agent deployment project to deploy ops-manager and pcf director.

## Global features

| name                          |                                         |
|-----------------------------------------|-----------------------------------------|
| **slack_updates**                       | Sends slack notification when a deployment finishes. |
| **update_deployment**                   | When enabled it will create update jobs for each of your environments. This can be useful when you do not want a new tile or stemcell to apply when deploying. |
| **pin_versions** (Requires concouse v5) | Pins resources to provided version through a yaml config file. |

## Environment Features

| name                                    |                                         |
|-----------------------------------------|-----------------------------------------|
| **allow_destroy**                       | When enabled it will add a destroy job to remove the boshrelease in the provided environment.  Recomended only for dev environments. |
| **backup**                              | `<opts>[daily, on_demand, on_updates]` Performs bbr backup and upload it to S3. |

