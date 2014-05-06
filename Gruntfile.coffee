
module.exports = (grunt) ->

  grunt.initConfig
    coffee:
      options:
        sourceMap: true
      'dist/tabangular.js': 'src/tabangular.coffee'
    uglify:
      'dist/tabangular.min.js' : 'dist/tabangular.js'
    watch:
      files: ["src/tabangular.coffee"]
      tasks: ["coffee","uglify"]

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.registerTask 'default', ['coffee', 'uglify']
