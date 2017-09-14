#!/bin/bash

# Software License Agreement - BSD License
#
# Inspired by MoveIt! travis https://github.com/ros-planning/moveit_core/blob/09bbc196dd4388ac8d81171620c239673b624cc4/.travis.yml
# Inspired by JSK travis https://github.com/jsk-ros-pkg/jsk_travis
# Inspired by ROS Industrial https://github.com/ros-industrial/industrial_ci
#
# Author:  Dave Coleman, Isaac I. Y. Saito, Robert Haschke
# Modified By: Gareth Ellis (For UBC Snowbots)

# Note: ROS_REPOSITORY_PATH is no longer a valid option, use ROS_REPO. See README.md

export CI_SOURCE_PATH=$(pwd) # The repository code in this pull request that we are testing
export CI_PARENT_DIR=.moveit_ci  # This is the folder name that is used in downstream repositories in order to point to this repo.
export HIT_ENDOFSCRIPT=false
export REPOSITORY_NAME=${PWD##*/}
export CATKIN_WS=/root/ws_moveit
# The version of clang to be used to verify formatting
export CLANG_VERSION=4.0
echo "---"
echo "Testing branch $TRAVIS_BRANCH of $REPOSITORY_NAME on $ROS_DISTRO"

# Check if we're doing formatting verification
# If we are doing format verification, that is ALL we'll do. We won't continue
# on below
if [ "$TEST_CLANG_FORMAT" == "TRUE" ]; then
    # Determine what we should compare this branch against to figure out what 
    # files were changed
    if [ "$TRAVIS_PULL_REQUEST" == "false" ] ; then
      # Not in a pull request, so compare against parent commit
      base_commit="HEAD^"
      echo "Running clang-format against parent commit $(git rev-parse $base_commit)"
      echo "=================================================="
    else
      # In a pull request so compare against branch we're trying to merge into
      base_commit="$TRAVIS_BRANCH"
      echo "Running clang-format against branch $base_commit, with hash $(git rev-parse $base_commit)"
    fi
    # Check if we need to change any files
    output="$(./.moveit_ci/git-clang-format --binary .moveit_ci/clang-format-$CLANG_VERSION --commit $base_commit --diff)"
    if [[ $output == *"no modified files to format"* ]] || [[ $output == *"clang-format did not modify any files"* ]] ; then
        echo "clang-format passed :D"
        exit 0
    else
        echo "$output"
        echo "=================================================="
        echo "clang-format failed :( - please reformat your code via the \`git clang-format\` tool and resubmit"
        exit 1
    fi
fi


# Helper functions
source ${CI_SOURCE_PATH}/$CI_PARENT_DIR/util.sh

# Run all CI in a Docker container
if ! [ "$IN_DOCKER" ]; then

    # Choose the correct CI container to use
    case "$ROS_REPO" in
        ros-shadow-fixed)
            export DOCKER_IMAGE=moveit/moveit:$ROS_DISTRO-ci-shadow-fixed
            ;;
        *)
            export DOCKER_IMAGE=moveit/moveit:$ROS_DISTRO-ci
            ;;
    esac
    echo "Starting Docker image: $DOCKER_IMAGE"

    # Pull first to allow us to hide console output
    docker pull $DOCKER_IMAGE > /dev/null

    # Start Docker container
    docker run \
        -e ROS_REPO \
        -e ROS_DISTRO \
        -e BEFORE_SCRIPT \
        -e CI_PARENT_DIR \
        -e UPSTREAM_WORKSPACE \
        -e TRAVIS_BRANCH \
        -e TEST_BLACKLIST \
        -v $(pwd):/root/$REPOSITORY_NAME $DOCKER_IMAGE \
        /bin/bash -c "cd /root/$REPOSITORY_NAME; source .moveit_ci/travis.sh;"
    return_value=$?

    if [ $return_value -eq 0 ]; then
        echo "$DOCKER_IMAGE container finished successfully"
        HIT_ENDOFSCRIPT=true;
        exit 0
    fi
    echo "$DOCKER_IMAGE container finished with errors"
    exit 1 # error
fi

# If we are here, we can assume we are inside a Docker container
echo "Inside Docker container"

# Update the sources
travis_run apt-get -qq update

# Setup rosdep - note: "rosdep init" is already setup in base ROS Docker image
travis_run rosdep update

# Create workspace
travis_run mkdir -p $CATKIN_WS/src
travis_run cd $CATKIN_WS/src

# Install dependencies necessary to run build using .rosinstall files
if [ ! "$UPSTREAM_WORKSPACE" ]; then
    export UPSTREAM_WORKSPACE="debian";
fi
case "$UPSTREAM_WORKSPACE" in
    debian)
        echo "Obtain deb binary for upstream packages."
        ;;
    http://* | https://*) # When UPSTREAM_WORKSPACE is an http url, use it directly
        travis_run wstool init .
        travis_run wstool merge $UPSTREAM_WORKSPACE
        ;;
    *) # Otherwise assume UPSTREAM_WORKSPACE is a local file path
        travis_run wstool init .
        if [ -e $CI_SOURCE_PATH/$UPSTREAM_WORKSPACE ]; then
            # install (maybe unreleased version) dependencies from source
            travis_run wstool merge file://$CI_SOURCE_PATH/$UPSTREAM_WORKSPACE
        else
            echo "No rosinstall file found, aborting" && exit 1
        fi
        ;;
esac

# download upstream packages into workspace
if [ -e .rosinstall ]; then
    # ensure that the downstream is not in .rosinstall
    # the exclamation mark means to ignore errors
    travis_run_true wstool rm $REPOSITORY_NAME
    travis_run cat .rosinstall
    travis_run wstool update
fi

# link in the repo we are testing
travis_run ln -s $CI_SOURCE_PATH .

# Debug: see the files in current folder
travis_run ls -a .

# Run before script
if [ "${BEFORE_SCRIPT// }" != "" ]; then
    travis_run sh -c "${BEFORE_SCRIPT}";
fi

# Change to base of workspace
travis_run cd $CATKIN_WS

# Install source-based package dependencies
# travis_run rosdep install -y -q -n --from-paths . --ignore-src --rosdistro $ROS_DISTRO

# Setup Catkin
# travis_run catkin config --extend /opt/ros/$ROS_DISTRO --install --cmake-args -DCMAKE_BUILD_TYPE=Release

# Change to base of workspace
travis_run cd $CATKIN_WS/src/$REPOSITORY_NAME
travis_run ./install_dependencies.sh

# Build the project
travis_run catkin_make

# Console output fix for: "WARNING: Could not encode unicode characters"
export PYTHONIOENCODING=UTF-8

# For a command that doesn’t produce output for more than 10 minutes, prefix it with my_travis_wait
#my_travis_wait 60 catkin build --no-status --summarize || exit 1

# Source the new built workspace
travis_run source devel/setup.sh

# Run tests
travis_run catkin_make run_tests

# Show test results and throw error if necessary
travis_run catkin_test_results

echo "Travis script has finished successfully"
HIT_ENDOFSCRIPT=true
exit 0
