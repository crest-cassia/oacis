function show_parameter_progress(url) {
  var margin = {top: 10, right: 0, bottom: 10, left: 0},
      width = 720,
      height = 720;
  var rowLabelMargin = 100;
  var columnLabelMargin = 100;

  var colorScale = d3.scale.linear().domain([0.0,1.0])
    .range(["#eeeeee", "#62c462"]);

  var cmap = d3.select('#color-map').append("svg")
    .attr("id", "color-map-svg")
    .attr("width", 200)
    .attr("height", 20);
  cmap.selectAll("rect")
    .data([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
    .enter().append("rect")
    .attr({
      x: function(d, i) { return i * 20.0;},
      y: 0.0,
      width: 19,
      height: 19,
      fill: function(d) { return colorScale(d); }
    });

  var toolTip = d3.select("div#progress-overview").append("div")
    .attr("class", "progress-tooltip")
    .style("opacity", 0);

  d3.json(url, function(dat) {

    var rectSizeX = (width - rowLabelMargin) / dat.parameter_values[0].length;
    var rectSizeY = (height - columnLabelMargin) / dat.parameter_values[1].length;

    var svg = d3.select("div#progress-overview").append("svg")
      .attr("id", "canvas")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
    
    var rectRegion = svg.append("g")
      .attr("transform", "translate(" + rowLabelMargin + "," + columnLabelMargin + ")");

    var row = rectRegion.selectAll("g")
      .data(dat.num_runs)
      .enter().append("g")
        .attr("transform", function(d, i) {
          return "translate(" + 0 + "," + i*rectSizeY + ")"
        });

    row.selectAll("rect")
      .data( function(d) { return d;})
        .enter().append("rect")
        .attr({
          x: function(d,i) {
            return i*rectSizeX;
          },
          y: 0,
          width: rectSizeX,
          height: rectSizeY,
          rx: 5,
          ry: 5,
          fill: function(d) {
            if( d != null ) { return colorScale(d[0]/d[1]); }
            else { return "white"; }
          },
          stroke: "white",
          "stroke-width": 2,
          "opacity": 0
        })
        .on("mouseover", function(d) {
          if( d != null ) {
            toolTip.transition()
              .duration(200)
              .style("opacity", .8);
            toolTip.html( "Finished/Total: " + d[0] + " / " + d[1] + "<br />Total: " + 100.0*d[0]/d[1] + " %")
              .style("left", d3.event.pageX + "px")
              .style("top", (d3.event.pageY-28) + "px");
          }
        })
        .on("mousemove", function(d) {
          toolTip.style("left", d3.event.pageX +  "px")
            .style("top", (d3.event.pageY-28) + "px");
        })
        .on("mouseout", function(d) {
          toolTip.transition()
            .duration(500)
            .style("opacity", 0);
        })
        .transition()
        .duration(1000)
        .delay( function(d,i) {return i*100;} )
        .attr({
          "opacity": function(d) {
            if( d != null ) { return 1.0; }
            else { return 0.0; }
          }
        });

    var rowLabelRegion = svg.append("g")
      .attr("transform", "translate(" + 0 + "," + columnLabelMargin + ")");
    rowLabelRegion.selectAll("text")
      .data(dat.parameter_values[1])
      .enter().append("text")
      .attr("x", rowLabelMargin)
      .attr("y", function(d,i) {
        return (i + 0.5) * rectSizeY;
      })
      .attr("text-anchor", "end")
      .text(function(d) { return dat.parameters[1] + " : " + d; });

    var columnLabelRegion = svg.append("g")
      .attr("transform", "translate(" + rowLabelMargin + "," + columnLabelMargin + ") rotate(-90)");
    columnLabelRegion.selectAll("text")
      .data(dat.parameter_values[0])
      .enter().append("text")
      .attr("x", 0)
      .attr("y", function(d,i) {
        return (i+0.5) * rectSizeX;
      })
      .attr("dx", "10")
      .attr("text-anchor", "start")
      .text(function(d) { return dat.parameters[0] + " : " + d; });
  })
};
