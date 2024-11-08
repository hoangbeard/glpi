def stage_title(message) {
    echo "\033[1;35m[Stage: ${message}]\033[0m"
}

def step_title(message) {
    echo "\033[1;33m[Step: ${message}]\033[0m"
}

def info(message) {
    echo "\033[34m[Info] ${message}\033[0m"
}

def error(message) {
    echo "\033[31m[Error] ${message}\033[0m"
}

def success(message) {
    echo "\033[32m[Success] ${message}\033[0m"
}

String AWS_REGION="ap-southeast-1"
String AWS_ACCOUNT_ID="698875276003"
String GIT_SSH_KEY_ID="bitbucket-ed25519"
String ENV="dev"
String APP_NAME="banktool"
String GIT_REPO_URL="git@bitbucket.org:mobivi/banktool-frontend.git"
String GIT_BRANCH="master"

def imageTag
def newTaskDefinitionArn

pipeline {
    agent any

    parameters {
        booleanParam defaultValue: true,
            description: 'Parameter to know if you want to rebuild the service.',
            name: 'BUILD'

        booleanParam defaultValue: true,
            description: 'Parameter to know if you want to deploy the service.',
            name: 'DEPLOY'
    }

    environment {
        // Establish resource access to AWS
        THE_BUTLER_SAYS_SO = credentials("${ENV}-jenkins-customized")
        AWS_ACCOUNT_ID = "${AWS_ACCOUNT_ID}"
        APP_ENV = "${ENV}"
        APP_NAME = "${APP_NAME}"
        AWS_REGION = "${AWS_REGION}"

        // ECS definitions
        ECS_CLUSTER_NAME = "${APP_ENV}-${APP_NAME}"
        ECS_SERVICE_NAME = "${APP_ENV}-${APP_NAME}-frontend"
        ECR_NAME = "${ECS_SERVICE_NAME}"
        ECR_REPO_URL = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_NAME}"
        ECS_TASK_DEFINITION_FAMILY = "${ECS_SERVICE_NAME}-taskdef"
        CONTAINER_NAME = "${ECS_SERVICE_NAME}"

        // Git repository
        GIT_REPO_URL = "${GIT_REPO_URL}"
        GIT_BRANCH = "${GIT_BRANCH}"

        // Fetch parameters and secrets
        BACKEND_URL = "http://${APP_ENV}-${APP_NAME}-backend.movi.${APP_ENV}:8080"
    }

    stages {
        stage('Checkout App Code') {
            when {
                anyOf {
                    environment name : 'BUILD', value: 'true'
                }
            }
            steps {
                stage_title('======== Checkout App Code ========')
                script {
                    dir('app-code-repo') {
                        // Checkout app code
                        step_title('Get code from git repository')
                        checkout scmGit(
                            branches: [[name: "*/${GIT_BRANCH}"]],
                            extensions: [cloneOption(depth: 1, noTags: false, reference: '', shallow: true)],
                            userRemoteConfigs: [[credentialsId: "${GIT_SSH_KEY_ID}",
                            url: "${GIT_REPO_URL}"]])

                        // Get commitID of git reposiroty
                        step_title('Get commitID of git reposiroty')
                        ecrTag = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()

                        // remove unnecessary directories and files
                        step_title('Remove unnecessary directories and files')
                        sh 'rm -rf .git'
                    }
                }
            }
        }

        stage('Fetch Configurations and Secrets') {
            when {
                anyOf {
                    environment name: 'BUILD', value: 'true'
                }
            }
            steps {
                stage_title('======== Fetch Configurations and Secrets ========')
                script {
                    // copy Dockerfile and nginx configuration files
                    step_title('Copy Dockerfile and nginx configuration files')
                    sh "cp -a ${APP_NAME}/frontend/docker/Dockerfile ${APP_NAME}/frontend/docker/nginx app-code-repo/"
                    sh "sed -i 's|\\\$BACKEND_URL|${BACKEND_URL}|g\' app-code-repo/nginx/conf.d/default.conf"

                    // copy application configuration files
                    step_title('Copy application configuration files')
                    sh "envsubst < ${APP_NAME}/frontend/docker/package.json.template > app-code-repo/package.json"
                    sh "envsubst < ${APP_NAME}/frontend/docker/setupProxy.js.template > app-code-repo/src/setupProxy.js"
                    sh "envsubst < ${APP_NAME}/frontend/docker/web.config.template > app-code-repo/iisConfig/web.config"
                }
            }
        }

        stage('Build and Push App Image') {
            when {
                anyOf {
                    environment name : 'BUILD', value: 'true'
                }
            }
            steps {
                stage_title('======== Build and Push Image ========')
                script {
                    dir('app-code-repo') {
                        // Login ECR
                        step_title('Login ECR')
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                        // Build and push image to ECR
                        step_title('Build and push image to ECR')
                        sh "docker buildx build \
                            --platform linux/amd64 \
                            --build-arg BUILDKIT_INLINE_CACHE=1 \
                            --build-arg APP_ENV=${APP_ENV} \
                            --build-arg APP_NAME=${APP_NAME} \
                            --push \
                            -t ${ECR_REPO_URL}:latest \
                            -t ${ECR_REPO_URL}:${ecrTag} \
                            ."
                    }
                }
            }
        }

        stage('Register Task Definition') {
            when {
                anyOf {
                    environment name : 'DEPLOY', value: 'true'
                }
            }
            steps {
                stage_title('======== Register Task Definition ========')
                script {
                    // Get image latest version if build skips
                    step_title('Get image latest version if build skips')
                    if (params.BUILD == false) {
                        ecrTag = sh(script: "aws ecr describe-images \
                            --repository-name ${ECR_NAME} \
                            --region ${AWS_REGION} \
                            --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]'", returnStdout: true).trim().replaceAll('"', '')

                        info("ecrTag: ${ecrTag}")
                    } else {
                        info("ecrTag: ${ecrTag}")
                    }

                    // rebuild ECR_URL
                    step_title('Rebuild ECR_URL')
                    def ECR_URL = "${ECR_REPO_URL}:${ecrTag}"

                    // Describe task definition to get current task definition
                    step_title('Describe task definition to get current task definition')
                    def describeTaskDef = sh(script: "aws ecs describe-task-definition \
                        --region ${AWS_REGION} \
                        --task-definition ${ECS_TASK_DEFINITION_FAMILY}", returnStdout: true).trim()

                    // Update image in task definition
                    step_title('Update image in task definition')
                    def newTaskDefContent = sh(script: """
                        echo '''${describeTaskDef}''' | jq --arg IMAGE '${ECR_URL}' --arg CONTAINER_NAME '${CONTAINER_NAME}' '
                        .taskDefinition |
                        .containerDefinitions |= map(if .name == \$CONTAINER_NAME then .image = \$IMAGE else . end) |
                        del(.taskDefinitionArn) |
                        del(.revision) |
                        del(.status) |
                        del(.requiresAttributes) |
                        del(.compatibilities) |
                        del(.registeredAt) |
                        del(.registeredBy)'
                    """, returnStdout: true).trim()

                    // Register new task definition
                    step_title('Register new task definition')
                    newTaskDefinitionArn = sh(script: "aws ecs register-task-definition \
                        --region ${AWS_REGION} \
                        --cli-input-json '${newTaskDefContent}' \
                        --query 'taskDefinition.taskDefinitionArn'", returnStdout: true).trim().replaceAll('"', '')

                    // Show new task definition arn
                    info("newTaskDefinitionArn: ${newTaskDefinitionArn}")
                }
            }
        }

        stage('Update ECS Service') {
            when {
                anyOf {
                    environment name : 'DEPLOY', value: 'true'
                }
            }
            steps {
                stage_title('======== Update ECS Service ========')
                script {
                    // Update ECS Service
                    step_title('Update ECS Service')
                    def resultUpdateService = sh(script: "aws ecs update-service --force-new-deployment \
                        --region ${AWS_REGION} \
                        --cluster ${ECS_CLUSTER_NAME} \
                        --service ${ECS_SERVICE_NAME} \
                        --task-definition ${newTaskDefinitionArn}", returnStdout: true).trim()

                    // Write result to JSON file
                    step_title('Write result to JSON file')
                    def resultUpdateServiceFileName = "jenkinswrite-${BUILD_NUMBER}-update-${ECS_SERVICE_NAME}-service-response.json"
                    writeJSON file: resultUpdateServiceFileName, json: resultUpdateService
                }
            }
        }
    }
    post{
        always{
            info("Cleaning up docker system and project folder")
            sh 'docker system prune -f'
            cleanWs(cleanWhenNotBuilt: false, deleteDirs: true, disableDeferredWipeout: true, notFailBuild: true, patterns: [[pattern: '**/jenkinswrite-*', type: 'EXCLUDE']])
        }
        success{
            success("Pipeline executed successfully")
        }
        failure{
            error("Pipeline execution failed")
        }
    }
}