function Plot() {
  this.row = d3.select("#plot").insert("div","div").attr("class", "row");
  this.plot_region = this.row.append("div").attr("class", "col-md-8");
  this.description = this.row.append("div").attr("class", "col-md-4");
  this.svg = this.plot_region.insert("svg")
    .attr({
      "width": this.width + this.margin.left + this.margin.right,
      "height": this.height + this.margin.top + this.margin.bottom
    });
  this.main_group = this.svg
    .append("g")
      .attr("transform", "translate(" + this.margin.left + "," + this.margin.top + ")");
}

Plot.prototype.margin = {top: 10, right: 100, bottom: 100, left: 120};
Plot.prototype.width = 560;
Plot.prototype.height = 460;
Plot.prototype.xScale = null;
Plot.prototype.yScale = null;
Plot.prototype.xAxis = null;
Plot.prototype.yAxis = null;
Plot.prototype.data = null;
Plot.prototype.url = null;
Plot.prototype.current_ps_id = null;
Plot.prototype.parameter_set_base_url = null;

Plot.prototype.Init = function(data, url, parameter_set_base_url, current_ps_id) {
  this.data = data;
  this.url = url;
  this.parameter_set_base_url = parameter_set_base_url;
  this.current_ps_id = current_ps_id;

  this.xAxis = d3.svg.axis().orient("bottom");
  this.yAxis = d3.svg.axis().orient("left");
  this.SetXScale("linear");
  this.SetYScale("linear");

  this.main_group.append("defs").append("clipPath")
    .attr("id", "clip")
    .append("rect")
    .attr("x", -5) // 5 is radius of large point
    .attr("y", -5) // 5 is radius of large point
    .attr("width", this.width+10) // (this.width + 5) + 5
    .attr("height", this.height+10); // (this.width + 5) + 5
};

Plot.prototype.Destructor = function() { this.row.remove(); };

Plot.prototype.AddAxis = function() {
  // X-Axis
  this.main_group.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + this.height + ")")
    .append("text")
      .style("text-anchor", "middle")
      .attr("x", this.width / 2.0)
      .attr("y", 50.0)
      .text(this.data.xlabel);

  // Y-Axis
  this.main_group.append("g")
    .attr("class", "y axis")
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -this.height/2)
      .attr("y", -50.0)
      .style("text-anchor", "middle")
      .text(this.data.ylabel);

  this.UpdateAxis();
  this.svg.selectAll('.axis line, .axis path')
    .style({
      "fill": "none",
      "stroke": "#000",
      "shape-rendering": "crispEdges"
    });
};

Plot.prototype.SetXScale = null;// IMPLEMENE ME
Plot.prototype.SetYScale = null;// IMPLEMENT ME

Plot.prototype.UpdateAxis = function() {
  this.main_group.select(".x.axis").call(this.xAxis);
  this.main_group.select(".y.axis").call(this.yAxis);
};

