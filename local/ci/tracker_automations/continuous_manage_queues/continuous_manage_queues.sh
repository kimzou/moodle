#!/usr/bin/env bash
# This script adds some automatisms helping to manage the integration queues:
#  - candidates queue: issues awaiting from integration not yet in current.
#  - current queue: issues under current integration.
#
# The automatisms are as follow:
#  A) Before release only! (normally 6 weeks of continuous before release)
#    1) Add the "integration_held" (+ standard comment) to new features & improvements issue missing it @ candidates.
#    2) Move "important" issues from candidates to current.
#    3) Move issues away from the candidates queue.
#      a) Before a date (last week), keep the current queue fed with bug issues when it's under a threshold.
#      b) After a date (last week), add the "integration_held" (+ standard comment) to bug issues.
#  B) After release only! (normally 2 weeks of on-sync continuous after release)
#    1) Move issues away from the candidates queue.
#      a) Keep the current queue fed with bug issues when it's under a threshold.
#      b) Add the "integration_held" (+ on-sync standard comment) to new features and improvements missing it @ candidates.
#
# The criteria to consider an issue "important" are:
#  1) It must be in the candidates queue, awaiting for integration.        |
#  2) It must not have the integration_held or security_held labels.      | => filter=14000
#  3) It must not have the "agreed_to_be_after_release" text in a comment.| => NOT filter = 21366
#  4) At least one of this is true:
#    a) The issue has a must-fix version.                                 | => filter = 21363
#    b) The issue has the mdlqa label.                                    | => labels IN (mdlqa)
#    c) The issue priority is critical or higher.                         | => priority IN (Critical, Blocker)
#    d) The issue is flagged as security issue.                           | => level IS NOT EMPTY
#    e) The issue belongs to some of these components:                    | => component IN (...)
#      - Privacy
#      - Automated functional tests (behat)
#      - Unit tests
#
# This job must be enabled only since freeze day to packaging day.
#
# Parameters:
#  jiraclicmd: fill execution path of the jira cli
#  jiraserver: jira server url we are going to connect to
#  jirauser: user that will perform the execution
#  jirapass: password of the user
#  releasedate: Release date, used to decide between A (before release) and B (after release) behaviors. YYYY-MM-DD.
#  lastweekdate: Last week date to decide between 2a - feed current and 2b - held bug issues. (YYY-MM-DD, defaults to release -1w)
#  currentmin: optional, number of issue under which the current queue will be fed from the candidates one.
#  movemax: optional, max number of issue that will be moved from candidates to current when under currentmin.
#  dryrun: don't perfomr any write operation, only reads. Defaults to empty (false).

# Let's go strict (exit on error)
set -e

# Verify everything is set
required="WORKSPACE jiraclicmd jiraserver jirauser jirapass releasedate"
for var in $required; do
    if [ -z "${!var}" ]; then
        echo "Error: ${var} environment variable is not defined. See the script comments."
        exit 1
    fi
done

# file where results will be sent
resultfile=$WORKSPACE/continuous_manage_queues.csv
echo -n > "${resultfile}"

# file where updated entries will be logged
logfile=$WORKSPACE/continuous_manage_queues.log

# Calculate some variables
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
basereq="${jiraclicmd} --server ${jiraserver} --user ${jirauser} --password ${jirapass}"
BUILD_TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

source ${mydir}/lib.sh # Add all the functions.

# Set defaults
currentmin=${currentmin:-6}
movemax=${movemax:-3}
lastweekdate=${lastweekdate:-$(date -d "${releasedate} -7day" +%Y-%m-%d)}
dryrun=${dryrun:-}

# Verify that $releasedata has a correct YYYY-MM-DD format
if [[ ! ${releasedate} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: \$releasedate. Incorrect YYYY-MM-DD format detected: ${releasedate}"
    exit 1
fi

# Verify that $lastweekdate has a correct YYYY-MM-DD format
if [[ ! ${lastweekdate} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: \$lastweekdate. Incorrect YYYY-MM-DD format detected: ${lastweekdate}"
    exit 1
fi

# Today
nowdate=$(date +%Y%m%d)

# Decide if we are going to proceed with behaviour A (before release) or behaviour B (after release)
behaviorAB=
if [ $nowdate -lt $(date -d "${releasedate}" +%Y%m%d) ]; then
    behaviorAB="before"
else
    behaviorAB="after"
fi

# Decide if we are going to proceed with behaviour A3a (before last week, keep current queue fed)
# or behaviour A3b (last-week, add the integration_held + standard last week message to any issue).
behaviorA3=
if [ $behaviorAB == "before" ]; then # Only calculate this before release.
    if [ $nowdate -lt $(date -d "${lastweekdate}" +%Y%m%d) ]; then
        behaviorA3="move"
    else
        behaviorA3="hold"
    fi
fi

if [ -n "${dryrun}" ]; then
    echo "Dry-run enabled, no changes will be performed to the tracker"
fi

# Behaviour A, before the release (normally the 6 weeks of continuous).

if [ $behaviorAB == "before" ]; then
    # A1, add the "integration_held" + standard comment to any new feature or improvement arriving to candidates.
    run_A1
    # A2, move "important" issues from candidates to current
    run_A2
    # A3, move all issues aways from candidates queue:
    if [ $behaviorA3 == "move" ]; then
        # A3a, keep the current queue fed with bug issues when it's under a threshold.
        run_A3a
    fi
    if [ $behaviorA3 == "hold" ]; then
        # A3b, add the "integration_held" + standard comment to any issue arriving to candidates.
        run_A3b
    fi
fi

# Behaviour B, after the release (normally the 2 weeks of on-sync).

if [ $behaviorAB == "after" ]; then
    # B1a, keep the current queue fed with bug issues when it's under a threshold.
    run_B1a
    # B1b, add the "integration_held" + standard on-sync comment to any new feature or improvement arriving to candidates.
    run_B1b
fi

# Remove the resultfile. We don't want to disclose those details.
rm -fr "${resultfile}"
