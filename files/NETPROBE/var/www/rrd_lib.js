/* Author: Oleg Klyudt <oleg.kludt@gmail.com>
 * Technical University of Munich, Chair of Network Architectures and Services
 * 27th August, 2012
 */
// Inheritance is implemented by a method of parasitic combination inheritance
// It makes use of prototype inheritance by Douglas Crockford and parasitic inheritance with object augmentation.
// In case of instance properties inheritance, a constructor stealing method is employed

/**
 *
 * @param o
 * @return {F}
 */
function object(o) {
    "use strict";
    //Creates shallow copy of Object passed in
    function F() {}
    F.prototype = o; //shallow copy
    // Upon return: instance.[[Prototype]] -> o.prototype
    return new F();
}

/**
 *
 * @param {Object} subType
 * @param {Object} superType
 */
function inheritPrototype(subType, superType) {
    "use strict";
    //Let's make a prototype object for subType object out of instance Object called _prototype
    var _prot = object(superType.prototype); //create object
    _prot.constructor = subType; //augment object
    subType.prototype = _prot; //assign object
}

/**
 * @param {String} str
 */
function log(str) {
    "use strict";
    window.console.log(str);
}

/**
 *
 * @return {XMLHttpRequest}
 */
function createXHR(){
    "use strict";
    if (typeof XMLHttpRequest !== "undefined") {
        return new XMLHttpRequest();
    }
    else if (typeof window.ActiveXObject !== "undefined") {
        if (typeof createXHR.activeXString !== "string") {
            var versions = ["MSXML2.XMLHttp.6.0", "MSXML2.XMLHttp.3.0",
                "MSXML2.XMLHttp"], i, len, tmp;
            for (i=0,len=versions.length; i < len; i++) {
                 try {
                    tmp = new window.ActiveXObject(versions[i]);
                     createXHR.activeXString = versions[i];
                    break;
                }
                 catch (ex) {
                    log("AJAX methods are not supported");
                }
            }
        }
        return new window.ActiveXObject(createXHR.activeXString);
    }
    else {
        throw new Error("No XHR object available.");
    }
}

// Dummy constructor of an object storing variables and functions being accessible by any derived objects
function BasicValues() {"use strict";}

// To shorten further references:
var commonPrototype = BasicValues.prototype;

// They can be shadowed in instances for customization purpose
commonPrototype.verbose = false;
commonPrototype.live = false;
commonPrototype.servUrl = "http://10.0.3.3/cgi-bin/getData"; //Consider extension addition according to lighttpd server configs

// This shared function is available through prototype inheritance to all derived objects
//Syntax: string EncodedUri = encodeUrl(uri_to_prepend, name1, value1 [,name2 ,value2]*);
//It returns string of type: uri_to_prepend?name1=value1&name2=value2 etc.

/**
 *
 * @param url
 * @param name
 * @param value
 * @return {String}
 */
commonPrototype.encodeUrl = function(url,name,value){
    "use strict";
    if (!url) {
        return "";
    }
    if (arguments.length%2 === 0) {
        throw "encodeUrl: number of arguments must be odd";
    }
    if (url.indexOf("?") === -1) {
        url += "?";
    }
    var len = arguments.length, i;
    for ( i = 1; i <= len - 1; ++i) {
        if (i % 2) { //noinspection JSLint
            url += encodeURIComponent(arguments[i]) + "=";
        }
        else url += encodeURIComponent(arguments[i]) + "&";
    }
    //cut off trailing &
    return url.slice(0,url.length-1);
};


function CdpContainer(set_id, con_func) {
    "use strict";
    (typeof con_func !== "string") ? this.con_func = "average" : this.con_func = con_func;
    if (typeof set_id !== "string")
        throw "Constructor CdpContainer: set_id must be string";
    else this.set_id = set_id;
    var that = this;
    //dataType property must be assigned separately
    //this.dataType = ["time","value"];
    this.cdpToShow = 100; // should be tailored to concrete plot by external manipulations
    var _intervalID = 0;
    var _parsedDataSet = [];
    var _rawDataSet; //JSON format server response converted into an object through parsing
    var _refreshTime = 10000; //60 sec on default. It's changed after first server reply processing
    var _refreshTimeChanged = false;
    var _sTime = 0; // means since very beginning of DB
    var _eTime = 0; // till very end
    this.compareTimes = function(start,end) {
        if ((typeof start !== "number" && start !== 'x') || (typeof end !== "number" && end !== 'x')) throw new Error("Arguments type assertion error, they must be numbers or strings 'x")
        if (start === 'x') return !!(end === _eTime);
        else if (end === 'x') return !!(start ===_sTime);
        else return !!(start == _sTime && end == _eTime);
    };
    this.setTimes = function(st, et) {
        if (typeof st !== 'number' || typeof et !== 'number' || st < 0 || et > 0) throw new Error('Arguments must be of number type');
        if (st % 1 !== 0 || et % 1 !== 0) throw new Error('Arguments must be integer');
        _sTime = parseInt((st / 1000).toFixed(0)); _eTime = parseInt((et / 1000).toFixed(0));

    };
    this.getData = function(startTime, endTime) {
        if (startTime !== undefined && endTime !== undefined) {
            if (typeof startTime !== "number" || typeof endTime !== "number") throw "Instance of CdpContainer: function _queryData: first two arguments must be of number primitive type";
            _sTime = parseInt((startTime / 1000).toFixed(0));
            _eTime = parseInt((endTime / 1000).toFixed(0));
            if (this.verbose) log("getData(): _sTime = "+_sTime+", _eTime = "+_eTime) && log("Ready to _queryData()");
        }

        _queryData();

    };

    function _queryData() {
        if (that.live === false) {
            if (_intervalID !== 0) {
                clearInterval(_intervalID);
                _intervalID = 0;
            }
            //_queryData();
        }
        //CdpContainer as being source of data points will be self updating for a given time scale (startTime, endTime)
        //in every _refreshTime intervals, which is received from source. In principle, no further invocations of this method are required.
        else {
            if (_intervalID === 0) {
                _intervalID = setInterval(_queryData, _refreshTime);
                _queryData();
            }
            if (_refreshTimeChanged && (_intervalID !== 0)) {
                clearInterval(_intervalID);
                _intervalID = setInterval(_queryData, _refreshTime);
                _refreshTimeChanged = false;
            }
            // Otherwise _queryDate still will be going in background taking on values from closure
        }

        if (typeof that.cdpToShow !== "number" || that.cdpToShow <= 0) {
            throw new Error("Instance of CdpContainer:" +
                "function _queryData: cdpToShow argument must be of number primitive type and bigger that zero");
        }
        var xhr = createXHR();
        //Receive response part
        xhr.onreadystatechange = function(){
            if (xhr.readyState === 4) { //4 == XHR data loaded and ready to use
                if ((xhr.status >= 200 && xhr.status < 300) || xhr.status === 304){ //Handling of different HTML response codes for different browsers and implementations
                    that.verbose && log("XHR response received");
                    _parseData(xhr);
                    if (_parsedDataSet.length !== 0) {
                        that.callBack(_parsedDataSet);
                    }
                    else {
                        if (that.verbose) {
                            log("Parsed CDP array received from server is empty. This stanza should not appear anyway," +
                                "it's an indication in parsing logic error, check _parseData() function");
                        }
                    }
                }
                else {
                    if (that.verbose) log("Server request failed. Status returned is " + xhr.status.toString());
                }
            }
        };
        //Send request part
        var encodedUri = that.encodeUrl(that.servUrl,"id",that.set_id,"stime",_sTime,"etime", _eTime, "cdpNum", that.cdpToShow, "cons_func", that.con_func, "pattern", "tstat");
        if(that.verbose) log("_queryData(): parsed URI:"+encodedUri);
        xhr.open("get", encodedUri, true);
        xhr.send(null);
    }

    function _parseData(xhr) {
        // JSON parsing is carried out here
        // Response is anticipated in JSON format as following:
        //{"status":value,"interval":value,"dataSet":[[time,value+]*]}
        //length of the data array = cdpToShow in case of status = 0 (means OK).
        //Every array element [time,value+] is read in as specified by the attribute dataType.
        //For example: dataType = ["time", "value", "value"]; Then data is anticipated as [[time, value, value]*]
        // The first element is the earliest by time value. Sorting in ascending time order must be performed by server side.
        try {
            _rawDataSet=JSON.parse(xhr.responseText,
                function(k, v){
                    if (v === null) return NaN;
                    return v;
                });
        }
        catch (er) {
            log("JSON parse error: " + er);
            _rawDataSet = null;
        }
        // Handler function for column number 'position' extraction out of 2-dimensional array
        var arr_extract = function(position) {
            return function(item) {
                return item[position];
            };
        };
        if (_rawDataSet.status < 3) { //means there is useful data to parse
            if (_refreshTime !== _rawDataSet.interval * 1000) {
                _refreshTimeChanged = true;
                _refreshTime = _rawDataSet.interval * 1000; //in seconds received, transformed into ms
            }
            _parsedDataSet = (function() {
                var arr = [], w , r, i;
                var timeLoc = that.dataType.indexOf("time");
                arr[0] = _rawDataSet.dataSet.map(arr_extract(timeLoc));
                for (w = 1, r = 0; r < that.dataType.length; ++r, ++w) {
                    if (r === timeLoc) ++r;
                    if (r === that.dataType.length) break;
                    arr[w] = _rawDataSet.dataSet.map(arr_extract(r));
                }
                for (i = 0; i < arr[0].length; ++i) {
                    arr[0][i] *= 1000; //transform all time values from seconds into ms
                }
                return arr;
            }());
        }
        //otherwise _parsedDataSet remains the same
        if (that.verbose) {
            switch(_rawDataSet.status) {
                case 0: log("Server response received and parsed. Status: ok"); break;
                case 1: log("Server response received and parsed. Status: cdpToShow value is too big. Reset to allowed maximum of 1000"); break;
                case 2: log("Server response received and parsed. Status: requested consolidation function is unknown. Default 'average' was used"); break;
                case 3: log("Server response received and parsed. Status: server could not parse request"); break;
                case 4: log("Server response received and parsed. Status: requested rrd DB file is missing or corrupted"); break;
                case 5: log("Server response received and parsed. Status: premature request to server, no new data available"); break;
                case 6:
                    log("Server response received and parsed. Status: application internal error, if __debug__ is True, then description follows:");
                    if (_rawDataSet.statusStr !== undefined) log(_rawDataSet.statusStr);
                    else log("__debug__ wasn't set to True");
                    break;

                default: log("Server response received and parsed. Status: unknown value");
            }
        }
    }
}

Object.defineProperty(CdpContainer, "dataType",{
    get: function() {
        "use strict";
        return this.dataType;
    },
    set: function(dataType) {
        "use strict";
        if (typeof dataType !== "array") this.dataType = ["time","value"];
        else this.dataType = dataType.map(function(item){ return item.toLowerCase().trim();});
        if (this.dataType.indexOf("time") < 0) {
            this.dataType = ["time","value"];
            throw new Error("dataType syntax error: 'time' string was not provided");
        }
    }
});

Object.defineProperty(CdpContainer, "callBack",{
    get: function() {
        "use strict";
        return this.callBack;
    },
    set: function(cBfunc) {
        "use strict";
        if (typeof cBfunc !== "function") throw new Error("callBack attribute must be assigned a function type object");
        else this.callBack =cBfunc;
    }
});

inheritPrototype(CdpContainer, BasicValues);