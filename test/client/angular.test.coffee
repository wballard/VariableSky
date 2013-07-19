VariableSkyTestController = ($scope) ->
  $scope.variableFromSky = "pants"
        
angular.element(document).ready ->
  angular.bootstrap(document, [])
  mocha.run()
