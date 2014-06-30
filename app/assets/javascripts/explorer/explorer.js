ScatterPlot.prototype.AddDescription = function(){};

function ParameterExplorer() {}

ParameterExplorer.prototype.parallel_coordinate_plot = null;
ParameterExplorer.prototype.scatter_plot = null;
ParameterExplorer.prototype.current_ps_id = null;
ParameterExplorer.prototype.current_xaxis_key = null;
ParameterExplorer.prototype.current_yaxis_key = null;

ParameterExplorer.prototype.show_progress_arc = function() {
  var g = this.scatter_plot.main_group.append("g")
    .attr({
      "transform": "translate(" + (this.scatter_plot.margin.left) + "," + (this.scatter_plot.margin.top) + ")",
      "id": "progress_arc_group"
    });
  var progress = show_loading_spin_arc(g, this.scatter_plot.width, this.scatter_plot.height);
  return progress;
};

ParameterExplorer.prototype.Init = function() {
  this.scatter_plot = new ScatterPlot();
  this.parallel_coordinate_plot = new ParallelCoordinatePlot();
  this.SetLogscaleCheckbox();
  this.EventBind();
  this.current_ps_id = $('td#current_ps_id').text();
  this.Update();
};

ParameterExplorer.prototype.Update = function() {
  var plot = this;
  var url = this.BuildScatterPlotURL(this.current_ps_id);

  var progress = this.show_progress_arc();

  var xhr = d3.json(url)
    .on("load", function(dat) {
    progress.remove();
    plot.scatter_plot.Destructor();
    plot.scatter_plot = new ScatterPlot();
    plot.scatter_plot.Init(dat, url, "/parameter_set/", plot.current_ps_id);
    plot.scatter_plot.Draw();
    if(plot.parallel_coordinate_plot.data) {
      plot.parallel_coordinate_plot.data = dat;
      plot.parallel_coordinate_plot.current_ps_id = plot.current_ps_id;
    } else {
      Object.keys(dat.data[0][0]).forEach(function(key) {
        plot.parallel_coordinate_plot.ranges[key] = $('td#ps_v_' + key).data('range');
      });
      plot.parallel_coordinate_plot.Init(dat, plot.current_ps_id);
    }
    plot.parallel_coordinate_plot.colorScale.domain(plot.scatter_plot.colorScale.domain());
    plot.parallel_coordinate_plot.Update();
    plot.LogscaleEvent("x", $("#xlog").prop('checked') );
    plot.LogscaleEvent("y", $("#ylog").prop('checked') );
    plot.BrushEvent(plot.current_xaxis_key);
    plot.BrushEvent(plot.current_yaxis_key);
    plot.SetResultRangeEvent();
  })
  .on("error", function() { console.log("error"); })
  .get();
  progress.on("mousedown", function(){
    xhr.abort();
    progress.remove();
  });
};

ParameterExplorer.prototype.MoveCurrentPs = function(e) {
  var plot = this;
  var url = $(e).data('neighbor-url').replace('PSID', this.current_ps_id);
  var target_key = $(e).attr("id").replace(/^ps_down_/,"").replace(/^ps_up_/,"");

  d3.json(url, function(error, json) {
    // update table
    var ps_id = json._id;
    plot.current_ps_id = ps_id;
    var param_values = json.v;
    for(var key in param_values) {
      $('#ps_v_'+key).text(param_values[key]);
    }

    plot.parallel_coordinate_plot.current_ps_id = ps_id;
    plot.parallel_coordinate_plot.Update();
    // update scatter plot
    if(target_key == plot.current_xaxis_key || target_key == plot.current_yaxis_key) {
      plot.scatter_plot.current_ps_id = ps_id;
      plot.scatter_plot.UpdatePlot();
    } else {
      plot.Update();
    }
  });
};

ParameterExplorer.prototype.BuildScatterPlotURL = function(ps_id) {
  var plot = this;
  this.current_xaxis_key = $('#scatter-plot-form #x_axis_key').val();
  this.current_yaxis_key = $('#scatter-plot-form #y_axis_key').val();
  var result = $('#scatter-plot-form #result').val();
  var irrelevants = $('#irrelevant-params').children("input:checkbox:checked").map(function() {
    return this.id;
  }).get();

  function range_modified_keys() {
    return Object.keys(plot.parallel_coordinate_plot.ranges).filter(function(key){
      return (!plot.parallel_coordinate_plot.brushes[key].empty());
    });
  }
  irrelevants = irrelevants.concat(range_modified_keys()).join(',');

  var url = $('#plot').data('scatter-plot-url').replace('PSID', ps_id);
  var range = {};
  range_modified_keys().forEach( function(key) {
    if(key != plot.current_xaxis_key && key != plot.current_yaxis_key) {
      range[key] = plot.parallel_coordinate_plot.GetCurrentRangeFor(key);
    }
  });
  var url_with_param = url +
    "?x_axis_key=" + encodeURIComponent(this.current_xaxis_key) +
    "&y_axis_key=" + encodeURIComponent(this.current_yaxis_key) +
    "&result=" + encodeURIComponent(result) +
    "&irrelevants=" + encodeURIComponent(irrelevants) +
    "&range=" + encodeURIComponent( JSON.stringify(range) );
  return url_with_param;
};

ParameterExplorer.prototype.EventBind = function() {
  var plot = this;
  this.parallel_coordinate_plot.on_brush_change = function(key) {
    plot.BrushEvent(key);
  };
};

ParameterExplorer.prototype.BrushEvent = function(key) {
  var plot = this;
  var domain = plot.parallel_coordinate_plot.GetCurrentRangeFor(key).concat();
  if(key == plot.current_xaxis_key) {
    plot.scatter_plot.SetXDomain(domain[0], domain[1]);
    plot.scatter_plot.UpdatePlot();
  } else if(key == plot.current_yaxis_key) {
    plot.scatter_plot.SetYDomain(domain[0], domain[1]);
    plot.scatter_plot.UpdatePlot();
  } else {
    plot.Update();
  }
};

ParameterExplorer.prototype.LogscaleEvent = function(axis, checked) {
  var plot = this;
  if(axis == "x") {
    if(checked) {
      plot.scatter_plot.SetXScale("log");
    } else {
      plot.scatter_plot.SetXScale("linear");
    }
  }
  if(axis == "y") {
    if(checked) {
      plot.scatter_plot.SetYScale("log");
    } else {
      plot.scatter_plot.SetYScale("linear");
    }
  }
};

ParameterExplorer.prototype.SetLogscaleCheckbox = function() {
  var plot = this;
  $("#xlog").on("change", function() {
    plot.LogscaleEvent("x", $(this).prop('checked'));
    var key = $('#scatter-plot-form #x_axis_key').val();
    plot.BrushEvent(key);
  });
  $("#ylog").on("change", function() {
    plot.LogscaleEvent("y", $(this).prop('checked'));
    var key = $('#scatter-plot-form #y_axis_key').val();
    plot.BrushEvent(key);
  });
};

ParameterExplorer.prototype.SetResultRangeEvent = function() {
  var plot = this;
  $("#range-max")
    .val(plot.scatter_plot.colorScale.domain()[2])
    .on("change", function() {
      var domain = plot.scatter_plot.colorScale.domain();
      try{
        if(isNaN(domain[2])) {
          alert("Do not change tha value \"NaN\"");
          this.value=""+domain[2];
          return;
        }
        if( isNaN(Number(this.value)) ) {
          alert(this.value + " is not a number");
          this.value=""+domain[2];
        } else if( Number(this.value) < domain[1] ) {
          alert(this.value + " is not greater than or equal to range mid. value");
          this.value=""+domain[2];
        } else {
          domain[2] = Number(this.value);
          plot.scatter_plot.colorScale.domain(domain);
          plot.scatter_plot.colorScalePoint.domain(domain);
          plot.parallel_coordinate_plot.colorScale.domain(domain);
          plot.scatter_plot.UpdatePlot();
          plot.parallel_coordinate_plot.Update();
        }
      } catch(e) {
        alert(e);
      }
    });
  $("#range-mid")
    .val(plot.scatter_plot.colorScale.domain()[1])
    .on("change", function() {
      var domain = plot.scatter_plot.colorScale.domain();
      try{
        if(isNaN(domain[1])) {
          alert("Do not change tha value \"NaN\"");
          this.value=""+domain[1];
          return;
        }
        if( isNaN(Number(this.value)) ) {
          alert(this.value + " is not a number");
          this.value=""+domain[1];
        } else if( Number(this.value) < domain[0] ) {
          alert(this.value + " is not greater than or equal to range min. value");
          this.value=""+domain[1];
        } else if( Number(this.value) > domain[2] ) {
          alert(this.value + " is not less than or equal to range max. value");
          this.value=""+domain[1];
        } else {
          domain[1] = Number(this.value);
          plot.scatter_plot.colorScale.domain(domain);
          plot.scatter_plot.colorScalePoint.domain(domain);
          plot.parallel_coordinate_plot.colorScale.domain(domain);
          plot.scatter_plot.UpdatePlot();
          plot.parallel_coordinate_plot.Update();
        }
      } catch(e) {
        alert(e);
      }
    });
  $("#range-min")
    .val(plot.scatter_plot.colorScale.domain()[0])
    .on("change", function() {
      var domain = plot.scatter_plot.colorScale.domain();
      try{
        if(isNaN(domain[0])) {
          alert("Do not change tha value \"NaN\"");
          this.value=""+domain[0];
          return;
        }
        if( isNaN(Number(this.value)) ) {
          alert(this.value + " is not a number");
          this.value=""+domain[0];
        } else if( Number(this.value) > domain[1] ) {
          alert(this.value + " is not less than or equal to range mid. value");
          this.value=""+domain[0];
        } else {
          domain[0] = Number(this.value);
          plot.scatter_plot.colorScale.domain(domain);
          plot.scatter_plot.colorScalePoint.domain(domain);
          plot.parallel_coordinate_plot.colorScale.domain(domain);
          plot.scatter_plot.UpdatePlot();
          plot.parallel_coordinate_plot.Update();
        }
      } catch(e) {
        alert(e);
      }
    });
};

