
thing = angular.module('test-app', [])
.controller 'VariableSkyTestController', ($scope) ->

angular.bootstrap(document, ['test-app'])
mocha.run()
