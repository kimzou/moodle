# Important to remember, always add the < /dev/null
# to every Jenkins CLI execution. Depending of the
# connection mode used, the CLI consumes all the
# STDIN, causing any outer loops (in caller scripts)
# to stop silently. This was discovered @ MDLSITE-5313
# and we need to keep it (until we move to REST from CLI)

# We want to launch always a sqlsrv PHPUNIT
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "phpunit" ]]; then
    echo -n "PHPUnit (sqlsrv): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.02 - Developer-requested PHPUnit" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=sqlsrv \
        -p PHPVERSION=7.2 \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# Disabled for now, it's failing a lot :-(
# We want to launch always a Behat (latest, @app only) job
#if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-app" ]]; then
#echo -n "App tests (experimental): " >> "${resultfile}.jenkinscli"
#${jenkinsreq} "DEV.01 - Developer-requested Behat" \
#    -p REPOSITORY=${repository} \
#    -p BRANCH=${branch} \
#    -p DATABASE=pgsql \
#    -p PHPVERSION=7.2 \
#    -p BROWSER=chrome \
#    -p BEHAT_TOTAL_RUNS=1 \
#    -p MOBILE_VERSION=latest \
#    -p INSTALL_PLUGINAPP=true \
#    -p TAGS=@app \
#    -w >> "${resultfile}.jenkinscli" < /dev/null
#fi

# We want to launch always a Behat (goutte) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-goutte" ]]; then
echo -n "Behat (goutte): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=7.2 \
        -p BROWSER=goutte \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi

# We want to launch always a Behat (chrome) job
if [[ "${jobtype}" == "all" ]] || [[ "${jobtype}" == "behat-chrome" ]]; then
    echo -n "Behat (chrome): " >> "${resultfile}.jenkinscli"
    ${jenkinsreq} "DEV.01 - Developer-requested Behat" \
        -p REPOSITORY=${repository} \
        -p BRANCH=${branch} \
        -p DATABASE=pgsql \
        -p PHPVERSION=7.2 \
        -p BROWSER=chrome \
        -w >> "${resultfile}.jenkinscli" < /dev/null
fi
