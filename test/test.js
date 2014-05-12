var test = angular.module('test', ['tabangular']);

test.config(function (TabsProvider) {
  TabsProvider.registerTabType("input", {
    templateURL: 'templates/input.html',
    controller: 'InputCtrl'
  });

  TabsProvider.setTabTypeFetcher(function ($window, deferred, typeID) {
    if (typeID === 'fetched') {
      $window.setTimeout(function () {
        deferred.resolve({
          templateString: '<h4>This junk was resolved: {{options.title}}</h4>',
          scope: false
        });
      })
    }
  });
});

function NestedCtrl ($scope, Tabs, Tab) {
  $scope.options = (Tab && Tab.options) || {title: "Main Page"};
  $scope.tabs = Tabs.newArea({id: $scope.options.title});
  $scope.tabs2 = Tabs.newArea({id: $scope.options.title + "2"});

  $scope.tabs.handleExisting(function (tab) {
    console.log(tab, tab.type === 'input');
    return tab.type === 'input';
  });

  $scope.tabs2.handleExisting(function (tab) {
    console.log(tab);
    return tab.type === 'input';
  });

  $scope.openInput = function (title) {
    $scope.tabs.open('input', {title: title})
  };

  $scope.openFetched = function () {
    $scope.tabs.open('fetched', {title: 'fetched'});
  };

  $scope.openDynamic = function (name) {
    var ctrl = function ($scope, Tab) {
      Tab.disableAutoClose();
      var off = null;


      $scope.loud = function () {
        off && off();
        off = Tab.on("close", function () {
          var yes = window.confirm("close " + name + "?");
          if (yes) {
            Tab.close(true);
          }
        });
        $scope.mode = "loud";
      };

      $scope.quiet = function () {
        off && off();
        off = Tab.on("close", function () {
          Tab.close(true);
        });
        $scope.mode = "quiet";
      };

      $scope.loud();
      
    };

    var template = "<div>"
                   + "<h4>"+name+" : {{mode}}</h4>"
                   + "<button ng-click='loud()' ng-show=\"mode == 'quiet'\">go loud</button>"
                   + "<button ng-click='quiet()' ng-show=\"mode == 'loud'\">go quiet</button>"
                 + "</div>";

    $scope.tabs.open({
      controller: ctrl,
      templateString: template 
    }, {title: name});
    
  };

  $scope.openNested = function (title) {
    $scope.tabs.open({
      controller: 'NestedCtrl',
      templateID: 'main.html'
    }, {title: title});
  }
}

test.controller('MainCtrl', function ($scope, Tabs) {
  NestedCtrl($scope, Tabs);
});

test.controller('InputCtrl', function ($scope, Tab) {
  Tab.deferLoading();
  $scope.options = Tab.options;
  setTimeout(function () { Tab.doneLoading(); }, 1000);
});