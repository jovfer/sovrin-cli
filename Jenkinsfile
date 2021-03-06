#!groovy

@Library('SovrinHelpers') _

properties([
        [$class: 'BuildDiscarderProperty', strategy: [
                $class               : 'LogRotator',
                artifactDaysToKeepStr: '28',
                artifactNumToKeepStr : '',
                daysToKeepStr        : '28',
                numToKeepStr         : ''
        ]]
]);

env.SOVRIN_CORE_REPO_NAME = 'test' //FIXME rm test line
env.SOVRIN_SDK_REPO_NAME = 'test' //FIXME rm test line

try {
    publishing()
    if (acceptanceTesting()) {
        releasing()
    }
    notifyingSuccess()
} catch (err) {
    notifyingFailure()
    throw err
}

def acceptanceTesting() {
    stage('Acceptance testing') {
        if (env.BRANCH_NAME == 'rc') {
            echo "${env.BRANCH_NAME}: acceptance testing"
            if (approval.check("default")) {
                return true
            }
        } else {
            echo "${env.BRANCH_NAME}: skip acceptance testing"
        }
        return false
    }
}

def releasing() {
    stage('Releasing') {
        if (env.BRANCH_NAME == 'rc') {
            publishingRCtoStable()
        }
    }
}

def notifyingSuccess() {
    currentBuild.result = "SUCCESS"
    node('ubuntu-master') {
        sendNotification.success('sovrin-cli')
    }
}

def notifyingFailure() {
    currentBuild.result = "FAILED"
    node('ubuntu-master') {
        sendNotification.fail([slack: true])
    }
}

def getVersion(key) {
    _commit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
    //FIXME repo
    _version = sh(returnStdout: true, script: "wget -q https://raw.githubusercontent.com/jovfer/sovrin-cli/$_commit/manifest.txt -O - | grep -E '^${key} =' | head -n1 | cut -f2 -d= | cut -f2 -d '\"'").trim()
    return _version
}

def publishing() {
    node('ubuntu') {
        stage('Publish Ubuntu Files') {
            try {
                echo 'Publish Ubuntu files: Checkout csm'
                checkout scm

                version = getVersion("version")
                genesisVersion = getVersion("genesis-version")
                indyCliVersion = getVersion("indy-cli-version")
                shortIndyCliVer = indyCliVersion.split('~')[0]

                echo "Parsed versions: self $version, genesis $genesisVersion, indy CLI $shortIndyCliVer ($indyCliVersion)"

                echo 'Publish Ubuntu files: Build docker image'
                testEnv = dockerHelpers.build('sovrin-cli', 'ci/ubuntu.dockerfile ci/',
                        "--build-arg genesis_version=${genesisVersion} --build-arg indy_cli_version=${indyCliVersion}")

                sovrinCliDebPublishing(testEnv, version)
                sovrinCliWinPublishing(testEnv, version, indyCliVersion, shortIndyCliVer)
            }
            finally {
                echo 'Publish Ubuntu files: Cleanup'
                step([$class: 'WsCleanup'])
            }
        }
    }

    return version
}

def sovrinCliWinPublishing(testEnv, version, indyCliVersion, shortIndyCliVer) {
    type = env.BRANCH_NAME
    number = env.BUILD_NUMBER

    indyCliDirVersion = indyCliVersion.replace('~', '-')

    out_zip_name = "sovrin-cli_${version}.zip"

    testEnv.inside {

        //FIXME stable
        sh "wget https://repo.sovrin.org/windows/indy-cli/master/${indyCliDirVersion}/indy-cli_${shortIndyCliVer}.zip -O indy-cli.zip"
        sh '''
            unzip indy-cli.zip -d sovrin-cli
            cp manifest.txt sovrin-cli/
            cp sovrin-cli-init-default-networks.bat sovrin-cli/
            cp /etc/sovrin/pool_transactions_live_genesis sovrin-cli/
            cp /etc/sovrin/pool_transactions_sandbox_genesis sovrin-cli/
        '''
        sh "zip -j -l $out_zip_name sovrin-cli/*"

        targetRemoteDir = "/var/repository/repos/windows/sovrin-cli/$type/$version-$number"

        sovrinSSH("mkdir -p $targetRemoteDir")
        sovrinSCP("$out_zip_name", targetRemoteDir)
    }
}

def sovrinCliDebPublishing(testEnv, version) {
    echo 'Publish Indy Cli deb files to Apt'

    dir('ci/sovrin-packaging') {
        downloadPackagingUtils()
    }

    testEnv.inside {
        def suffix = "~$env.BUILD_NUMBER"

        sh 'cp sovrin-cli-init-default-networks.sh ci/sovrin-cli-init-default-networks'

        withCredentials([file(credentialsId: 'SovrinRepoSSHKey', variable: 'sovrin_key')]) {
            sh "cd ci && ./sovrin-cli-deb-build-and-upload.sh $version $env.BRANCH_NAME $suffix $SOVRIN_SDK_REPO_NAME $SOVRIN_REPO_HOST '$sovrin_key'"

            if (env.BRANCH_NAME == 'rc') {
                stash includes: './debs/*', name: 'sovrinCliDebs'
            }
        }
    }
}

def publishingRCtoStable() {
    node('ubuntu') {
        stage('Moving RC artifacts to Stable') {
            try {
                echo 'Moving RC artifacts to Stable: Checkout csm'
                checkout scm

                version = getSrcVersion()

                echo 'Moving RC artifacts to Stable: Build docker image for wrappers publishing'
                testEnv = dockerHelpers.build('sovrin-cli', 'ci/ubuntu.dockerfile ci/',
                        "--build-arg genesis_version=${genesisVersion} --build-arg indy_cli_version=${indyCliVersion}")

                echo 'Moving Ubuntu RC artifacts to Stable: indy-cli'
                publishLibindyCliDebRCtoStable(testEnv, version)

                echo 'Moving Windows RC artifacts to Stable: indy-cli'
                publishLibindyCliWindowsFilesRCtoStable(version)
            } finally {
                echo 'Moving RC artifacts to Stable: Cleanup'
                step([$class: 'WsCleanup'])
            }
        }
    }
}

def publishLibindyCliWindowsFilesRCtoStable(version) {
    rcFullVersion = "${version}-${env.BUILD_NUMBER}"
    src = "/var/repository/repos/windows/sovrin-cli/rc/$rcFullVersion/"
    target = "/var/repository/repos/windows/sovrin-cli/stable/$version"
    sovrinSSH("! ls $target")
    sovrinSSH("cp -r $src $target")
}

def publishLibindyCliDebRCtoStable(testEnv, version) {
    testEnv.inside {
        rcFullVersion = "${version}~${env.BUILD_NUMBER}"

        unstash name: 'sovrinCliDebs'

        sh "fakeroot deb-reversion -v $version ./debs/sovrin-cli_\"$rcFullVersion\"_amd64.deb"

        uploadDebianFilesToStable()
    }
}

def uploadDebianFilesToStable() {
    withCredentials([file(credentialsId: 'SovrinRepoSSHKey', variable: 'sovrin_key')]) {
        downloadPackagingUtils()
        path = sh(returnStdout: true, script: 'pwd').trim()

        sh "./upload_debs.py $path $SOVRIN_SDK_REPO_NAME stable --host $SOVRIN_REPO_HOST --ssh-key $sovrin_key"
    }
}

def downloadPackagingUtils() {
    git branch: 'master', credentialsId: 'evernym-github-machine-user', url: 'https://github.com/evernym/sovrin-packaging'
}

def sovrinSSH(cmd) {
    withCredentials([file(credentialsId: 'SovrinRepoSSHKey', variable: 'sovrin_repo_key')]) {
        sh "ssh -v -oStrictHostKeyChecking=no -i '$sovrin_repo_key' repo@192.168.11.115 '$cmd'"
    }
}

def sovrinSCP(from, toServer) {
    withCredentials([file(credentialsId: 'SovrinRepoSSHKey', variable: 'sovrin_repo_key')]) {
        sh "scp -v -oStrictHostKeyChecking=no -i '$sovrin_repo_key' $from repo@192.168.11.115:$toServer"
    }
}