
thing = angular.module('test-app', [])
.controller 'VariableSkyTestController', ($scope) ->
  console.log "controller"
  $scope.variableFromSky = "pants"

console.log(thing)
angular.bootstrap(document, ['test-app'])
mocha.run()

console.log "i has loaded at all"
