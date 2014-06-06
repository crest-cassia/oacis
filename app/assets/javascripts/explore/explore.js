function ParameterExplore() {
};

ParameterExplore.prototype.pc_plot = null;
ParameterExplore.prototype.scatter_plot = null;
ParameterExplore.prototype.current_ranges = {};

ParameterExplore.prototype.show_progress_arc = function() {
  var g = this.scatter_plot.svg.append("g")
    .attr({
      "transform": "translate(" + (this.scatter_plot.margin.left) + "," + (this.scatter_plot.margin.top) + ")",
      "id": "progress_arc_group"
    });
  var progress = show_loading_spin_arc(g, this.scatter_plot.width, this.scatter_plot.height);
  return progress;
};

ParameterExplore.prototype.Init = function() {
  var plot = this;
  this.scatter_plot = new ScatterPlot();
  this.pc_plot = new ParallelCoordinatePlot(this);
  var current_ps_id = this.get_current_ps();
  var url = this.BuildScatterPlotURL(current_ps_id);

  var progress = this.show_progress_arc();

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.scatter_plot.Init(dat, url, "/parameter_set/", current_ps_id);
    plot.scatter_plot.Draw();
    plot.pc_plot.Init(dat);
    plot.pc_plot.Update();
  })
  .on("error", function() { console.log("error"); })
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    progress.remove();
  });
}

ParameterExplore.prototype.Update = function() {
  var plot = this;
  var current_ps_id = this.get_current_ps();
  var url = this.BuildScatterPlotURL(current_ps_id);

  var progress = this.show_progress_arc();

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.scatter_plot.Destructor();
    plot.scatter_plot = new ScatterPlot();
    plot.scatter_plot.Init(dat, url, "/parameter_set/", current_ps_id);
    plot.scatter_plot.Draw();
    plot.pc_plot.data = dat;
    plot.pc_plot.Update();
  })
  .on("error", function() { console.log("error"); })
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    progress.remove();
  });
};

ParameterExplore.prototype.UpdateScatterPlot = function() {
  var plot = this;
  var current_ps_id = this.get_current_ps();
  var url = this.BuildScatterPlotURL(current_ps_id);

  var progress = this.show_progress_arc();

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.scatter_plot.Destructor();
    plot.scatter_plot = new ScatterPlot();
    plot.scatter_plot.Init(dat, url, "/parameter_set/", current_ps_id);
    plot.scatter_plot.Draw();
    plot.pc_plot.data = dat;
    plot.pc_plot.Update();
  })
  .on("error", function() { console.log("error"); })
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    progress.remove();
  });
};

ParameterExplore.prototype.get_current_ps = function() {
  return $('#current_ps_id').text();
};

ParameterExplore.prototype.MoveCurrentPs = function(neighbor_ps_url) {
  var plot = this;
  var current_ps_id = this.get_current_ps();
  var url = neighbor_ps_url.replace('PSID', current_ps_id);

  d3.json(url, function(error, json) {
    // update table
    var ps_id = json._id;
    $('#current_ps_id').text(ps_id);
    var param_values = json.v;
    for(var key in param_values) {
      $('#ps_v_'+key).text(param_values[key]);
    }

    plot.pc_plot.Update();
    // update scatter plot
    if(neighbor_ps_url.search($("select#x_axis_key").val())!=-1 || neighbor_ps_url.search($("select#y_axis_key").val())!=-1) {
      plot.scatter_plot.current_ps_id = ps_id;
    } else {
      plot.UpdateScatterPlot();
    }
  });
};

ParameterExplore.prototype.BuildScatterPlotURL = function(ps_id) {
  var plot = this;
  ps_id = ps_id || $('td#current_ps_id').text();
  var x = $('#scatter-plot-form #x_axis_key').val();
  var y = $('#scatter-plot-form #y_axis_key').val();
  var result = $('#scatter-plot-form #result').val();
  var irrelevants = $('#irrelevant-params').children("input:checkbox:checked").map(function() {
    return this.id;
  }).get();

  function range_modified_keys() {
    return Object.keys(plot.current_ranges).filter(function(key){
      return (!plot.pc_plot.brushes[key].empty());
    });
  }
  irrelevants = irrelevants.concat(range_modified_keys()).join(',');

  var url = $('#plot').data('scatter-plot-url').replace('PSID', ps_id);
  var range = {};
  range_modified_keys().forEach( function(key) {
    if(key != x && key != y) {
      range[key] = plot.GetCurrentRangeFor(key);
    }
  });
  var url_with_param = url +
    "?x_axis_key=" + encodeURIComponent(x) +
    "&y_axis_key=" + encodeURIComponent(y) +
    "&result=" + encodeURIComponent(result) +
    "&irrelevants=" + encodeURIComponent(irrelevants) +
    "&range=" + encodeURIComponent( JSON.stringify(range) );
  return url_with_param;
};

ParameterExplore.prototype.GetCurrentRangeFor = function(parameter_key) {
  if(!this.current_ranges[parameter_key]) {
    this.current_ranges[parameter_key] = $('td#ps_v_' + parameter_key).data('range');
  }
  return this.current_ranges[parameter_key];
};

ParameterExplore.prototype.SetCurrentRangeFor = function(parameter_key, range) {
  var new_range = (range) ? range : $('td#ps_v_' + parameter_key).data('range');
  this.current_ranges[parameter_key] = new_range;
};


