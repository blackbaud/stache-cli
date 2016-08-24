module.exports = function (grunt) {
  var exec,
      merge,
      path;

  path = require('path');
  exec = require('child_process').execSync;
  merge = require('merge');

  function getConfigEnvironmentString() {
    var config,
        env,
        filePath,
        k;

    filePath = grunt.option('config');
    config = grunt.file.readYAML('stache.deploy.yml');
    env = [];

    // Merge deployment config.
    if (filePath && grunt.file.exists(filePath)) {
      config = merge.recursive(true, config, grunt.file.readYAML(filePath));
    }

    // Create a string of environment variables.
    for (k in config.env) {
      if (config.env.hasOwnProperty(k)) {
        env.push(k + '=' + config.env[k]);
      }
    }
    env = env.join(' ') + ' ';
    return env;
  }

  function taskCliVersion() {
    grunt.log.writeln('Current stache-cli version: ' + grunt.file.readJSON('package.json').version);
  }

  function taskCopyBuild() {
    var env;
    env = getConfigEnvironmentString();
    grunt.task.run('shell:commitBuild:' + env);
  }

  function taskDeploy() {
    var env;
    env = getConfigEnvironmentString();
    grunt.task.run('cliversion');
    grunt.task.run('shell:deploy:' + env);
  }

  function taskFixIgnore() {
    var dir = grunt.config('boilerplateDest') + '/';
    grunt.file.copy(dir + '.npmignore', dir + '.gitignore');
    grunt.file.delete(dir + '.npmignore', { force: true });
  }

  function taskNew(dir) {
    dir = grunt.option('cwd') + dir;
    if (!dir) {
      grunt.fail.fatal('Please specify a folder.');
    } else if (dir.indexOf('.') === -1 && grunt.file.exists(dir)) {
      grunt.fail.fatal('The folder "' + dir + '" must not exist.');
    } else {
      grunt.config('boilerplateDest', dir);
      grunt.task.run('copy:boilerplate');
      grunt.task.run('fixIgnore');
    }
  }

  function taskRelease(type) {
    type = type || 'patch';
    exec('grunt --base ' + grunt.option('cwd') + ' bump:' + type, {
      cwd: path.resolve(),
      stdio: 'inherit'
    });
  }

  // Load necessary modules
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-bump');
  grunt.loadNpmTasks('grunt-shell');

  // Register our tasks
  grunt.registerTask(
    'cliversion',
    'Displays the current installed cli version',
    taskCliVersion
  );

  grunt.registerTask(
    'deploy',
    'Deploys the current project',
    taskDeploy
  );

  grunt.registerTask(
    'commitBuild',
    'Copies the results of a Travis-CI build to the deploy branch',
    taskCopyBuild
  );

  grunt.registerTask(
    'fixIgnore',
    'Copies the npmignore file to a gitignore',
    taskFixIgnore
  );

  grunt.registerTask(
    'new',
    'Create a new site using the STACHE boilerplate.',
    taskNew
  );

  grunt.registerTask(
    'release',
    'Create a new release branch and commit to upstream.',
    taskRelease
  );

  // Configure necessary modules
  grunt.config.init({
    bump: {
      options: {
        files: ['package.json'],
        updateConfigs: [],
        commit: true,
        commitMessage: 'Release v%VERSION%',
        commitFiles: ['package.json'],
        createTag: false,
        tagName: 'v%VERSION%',
        tagMessage: 'Version %VERSION%',
        push: true,
        pushTo: 'origin',
        gitDescribeOptions: '--tags --always --abbrev=1 --dirty=-d',
        globalReplace: false,
        prereleaseName: false,
        metadata: '',
        regExp: false
      }
    },
    copy: {
      boilerplate: {
        files: [
          {
            dot: true,
            expand: true,
            cwd: 'stache-boilerplate/',
            src: '**',
            dest: '<%= boilerplateDest %>'
          }
        ]
      }
    },
    shell: {
      options: {
        execOptions: {
          cwd: grunt.option('cwd'),
          stdout: true
        }
      },
      commitBuild: {
        command: function (env) {
          return env + 'bash ' + grunt.option('cli') + 'scripts/commit-build.sh';
        }
      },
      deploy: {
        command: function (env) {
          return env + 'bash ' + grunt.option('cli') + 'scripts/deploy.sh';
        }
      }
    }
  });
};
