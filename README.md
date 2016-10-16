# MoveIt Continous Integration
Common Travis CI configuration for MoveIt! project

Authors: Dave Coleman, Isaac I. Y. Saito, Robert Haschke
Modified By: Gareth Ellis (For UBC Snowbots)

- Uses Docker for all Distros
  - Travis does not currently support Ubuntu 16.04
  - Based on OSRF's pre-build ROS Docker container to save setup time
  - Uses MoveIt's pre-build Docker container to additionally save setup time
- Clean Travis log files - looks similiar to a regular .travis.yml file
- Runs tests for the current repo, e.g. if testing moveit\_core only runs tests for moveit\_core
- Builds into install space

## Usage

Create a ``.travis.yml`` file in the base of you repo similar to:

```
# This config file for Travis CI utilizes https://github.com/UBC-Snowbots/moveit_ci/ package.
sudo: required
dist: trusty
services:
  - docker
language: generic
compiler:
  - gcc
notifications:
  email:
    recipients:
        gareth.ellis0@gmail.com
env:
  matrix:
    - ROS_DISTRO=kinetic  ROS_REPO=ros              UPSTREAM_WORKSPACE=https://raw.githubusercontent.com/UBC-Snowbots/IGVC-2017/travis_ci_testing/.rosinstall
    - ROS_DISTRO=kinetic  UPSTREAM_WORKSPACE=https://raw.githubusercontent.com/UBC-Snowbots/IGVC-2017/travis_ci_testing/.rosinstall
matrix:
  allow_failures:
      - env: ROS_DISTRO=kinetic  ROS_REPO=ros              UPSTREAM_WORKSPACE=https://raw.githubusercontent.com/UBC-Snowbots/IGVC-2017/travis_ci_testing/.rosinstall
before_script:
    # Below line is not being used, as we are using a forked version
#    - git clone -q https://github.com/ros-planning/moveit_ci.git .moveit_ci
    - git clone -q https://github.com/UBC-Snowbots/moveit_ci .moveit_ci
script:
  - source .moveit_ci/travis.sh
```

## Configurations

- ROS_DISTRO: (required) which version of ROS i.e. kinetic
- ROS_REPO: (default: ros-shadow-fixed) install ROS debians from either regular release or from shadow-fixed, i.e. http://packages.ros.org/ros-shadow-fixed/ubuntu
- BEFORE_SCRIPT: (default: not set): Used to specify shell commands or scripts that run before building packages.
- UPSTREAM_WORKSPACE (default: debian): When set as "file", the dependended packages that need to be built from source are downloaded based on a .rosinstall file in your repository. When set to a "http" URL, this downloads the rosinstall configuration from an http location

More configurations as seen in [industrial_ci](https://github.com/ros-industrial/industrial_ci) can be added, in the future.

## Removed Configuration

- ROS_REPOSITORY\_PATH: (UNSUPPORTED) replaced by ROS\_REPO

## Running Locally For Testing

To manually run the moveit_ci script without Travis (presumably for testing):

First clone the repo you want to test:

    cd ~/
    git clone https://github.com/davetcoleman/moveit_kinetic_cpp11
    cd moveit_kinetic_cpp11

Next clone the CI script:

    git clone https://github.com/UBC-Snowbots/moveit_ci .moveit_ci

Define the necessary environmental variables:

    export ROS_DISTRO=kinetic
    export ROS_REPO=ros-shadow-fixed
    export UPSTREAM_WORKSPACE=.rosinstall

Start the script

    .moveit_ci/travis.sh
