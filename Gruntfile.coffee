
module.exports = (grunt) ->

  grunt.initConfig
    coffee:
      options:
        sourceMap: true
      'tabangular.js': 'tabangular.coffee'
    uglify:
      'tabangular.min.js' : 'tabangular.js'
      options:
        sourceMapIn : 'tabangular.js.map'
        sourceMap : true
    watch:
      files: ["src/tabangular.coffee"]
      tasks: ["coffee","uglify"]

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.registerTask 'default', ['coffee', 'uglify']
