(function (GGRC, Generator) {
  GGRC.Bootstrap.Mockups = GGRC.Bootstrap.Mockups || {};
  GGRC.Bootstrap.Mockups.QDashboard = GGRC.Bootstrap.Mockups.QDashboard || {};

  GGRC.Bootstrap.Mockups.QDashboard.Info = {
    title: 'Info',
    icon: 'info-circle',
    template: '/quick-workflow-v2.1-dashboard/info.mustache',
    tasks: Generator.create({
      type: 'task'
    })
  };
})(GGRC || {}, GGRC.Mockup.Generator);
