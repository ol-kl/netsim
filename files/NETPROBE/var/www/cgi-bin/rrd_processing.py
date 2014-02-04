#!/usr/bin/python3.3

# This module makes use of python written lib ElementTree instead of C one
# in order to extend a parser class of ElementTree module to process XML 
# comments. C built-in class implementation cannot be extended via inheritance.

# Pros: times corresponding to data points are now directly extracted from DB comments,
# therefore they are 100% precise.

# Cons: Processing load is immense compared to C implementation.

# Original module rrd_processing employs heuristics to calculate relevant times
# of data samples based on "pdp_per_row" and "lastupdate" data fields in XML dump
# of RRD. These calculations are based on assumption that at the indicated time
# moment "lastupdate" all RRAs were updated (sort of aligned in time) and all
# "pdp_per_row" counters are reseted to zero to initiate counting anew.
# This assumption is way not always true, equally as any other. 
# At the moment I failed to find more precise approach or heuristics
# to find those times precisely without looking into comment fields,
# where those values are stored.
'''
Created on 28.08.2012
Last modified on 10.10.2012
@contact: <oleg.kludt@gmail.com>
@author: Oleg Klyudt 
@copyright: Technical University of Munich, Chair of Network Architectures and Services
@version: October 2012

The module implements a stand-alone application to extract time, data pairs from
RRD data base and return them after processing back to a client in a form of JSON string
The application read and write in UNIX socket file /tmp/fastcgi.python.socket, even though
it can be configured to get started by a web-server and read & write from/to stdin/stdout

ATTENTION! Permissions of a socket file must be taken care of by external means (utils),
otherwise (in most cases) web server will lack for permissions to write to the socket.

This particular realization makes use of a bundle:
webserver <--> fastCGI interface <--> WSGI interface <--> this application
In principle, the app doesn't depend on a particular WSGI server realization,
it just must be compliant to specs PEP3333 one. 

Source files server.fcgi, server.threadpool, server.fcgi_base were ported to Python 3.2.3.
Also fallback to regular CGI was added due to lack of support of the function socket.fromfd()
on windows (windows uses file handles instead of file descriptors)
Some bugs and inconsistences were also fixed
'''

import xml.etree.ElementTree as ET
import os
import math
import subprocess
import itertools
import time
import json
import cgi

class PIParser(ET.XMLTreeBuilder): #@UndefinedVariable
    """
    Extension of parser class to incorporate XML comments
    processing 
    """

    def __init__(self):
        ET.XMLTreeBuilder.__init__(self) #@UndefinedVariable
        # assumes ElementTree 1.2.X
        self._parser.CommentHandler = self.handle_comment
        self._parser.ProcessingInstructionHandler = self.handle_pi
        self._target.start("document", {})

    def close(self):
        self._target.end("document")
        return ET.XMLTreeBuilder.close(self) #@UndefinedVariable

    def handle_comment(self, data):
        self._target.start(ET.Comment, {}) #@UndefinedVariable
        idx = data.find('/')
        if idx != -1 and str.isdecimal(data[idx+1:].strip()):
            self._target.data(data[idx+1:].strip())
        else:
            self._target.data(data)
        self._target.end(ET.Comment) #@UndefinedVariable

    def handle_pi(self, target, data):
        self._target.start(ET.PI, {}) #@UndefinedVariable
        self._target.data(target + " " + data)
        self._target.end(ET.PI) #@UndefinedVariable

def parse(text):
    parser = PIParser()
    parser.feed(text)
    return parser.close()

class ProcessingEnd(Exception):
    """
    Raise this class exception to dispatch sentData bytes string 
    back to FCGI back-end
    """
    def __init__(self, sentData = b'', report='omitted'):
        self.report = report 
        self.sentData = sentData

class RequestDispatcher:
    """
    It handles requests from web-server, instantiating objects of type WorkerTstat
    for every DB file. Return requested data. It's also responsible
    for persistence of DB state across requests
    """
    def __init__(self):
        self.pool = {}
        # 5 min timeout for storing WorkerTstat class in memory
        # in case no incoming requests for that class have been arriving
        self._timeout = 600 
        
    def dispatch(self, env, start_response):
        """
        It's responsible for instantiating a WorkerTstat objects to handle
        DB files (if they weren't yet, it's a sort of Singleton pattern
        in OOP), for removing orphaned those objects, if they are not addressed
        within timeout, for querying those objects using fetchDB method
        to retrieve data and for returning the data to WSGI server.
        """
        start_response('200 OK', [('Content-Type', 'text/plain')])
        
        form = cgi.FieldStorage(fp=env['wsgi.input'], environ=env,
                                keep_blank_values=1)
        getVal = form.getfirst
        for name in iter(['id','stime','etime','cons_func',\
                          'cdpNum','pattern']):
            if getVal(name) == None:
                #import pdb; pdb.set_trace()
                return iter([json.dumps({'status':3}).encode()])
                #return iter([json.dumps(env).encode()])
            
        # Customization for other patterns is also possible
        if getVal('pattern') == 'tstat':
            if getVal('id') not in self.pool:
                try:
                    tmp = WorkerTstat(getVal('id'))
                #if __init__ raise exception (due to sanitization failure):   
                except ProcessingEnd as obj:
                    return iter([obj.sentData])
                self.pool[getVal('id')] = tmp
                
            worker = self.pool[getVal('id')]
            worker.lastReceivedReqTime = int(time.time())
            
            # Cleaning here: delete DB object if timeout is exceeded
            itemsToDelete = []
            try:
                for (db_name, db_obj) in iter(self.pool.items()):
                    if worker.lastReceivedReqTime - db_obj.lastReceivedReqTime > self._timeout:
                        itemsToDelete.append(db_name)
                
                for i in range(len(itemsToDelete)):
                    del self.pool[itemsToDelete.pop()]
            except RuntimeError:
                return iter([json.dumps({'status':6,'statusStr':'dispatch() Error while deleting '}).encode()])
                       
            try:
                worker.fetchDB(getVal('stime'), getVal('etime'),\
                           getVal('cons_func'), getVal('cdpNum'))
            except ProcessingEnd as obj:
                worker.bstrToSend = obj.sentData
                return iter([obj.sentData])
            else:
                _str = 'Unknown type of exception was caught'
                return iter([json.dumps({'status':6,'statusStr':_str}).encode()])
        else:
            _str = 'Unknown pattern'
            return iter([json.dumps({'status':3,'statusStr':_str}).encode()])

class WorkerTstat:
#    def __new__(cls, pool, stime, etime, cf, set_id):
#        if set_id in pool:
#            return pool[set_id]
#        else:
#            pool[set_id] = super().__new__(cls, stime, etime, cf, set_id)
#            return pool[set_id] 
    
    def __init__(self, set_id):
        self.bstrToSend = b'' # is manipulated upon by external facilities
        # self.paths is customizable for including any other paths to look for DB files
        self.paths = ['/var/www/cgi-bin/', '/var/www/databases/']
        self.fileState = object() # It's overridden with every DB file access
        self.lastQueryTime = int(time.time())
        self.lastReceivedReqTime = int(time.time())
        self.status = 0
        self.stime = 0
        self.etime = 0
        self.cf = 'average'
        self.cdpToShow = 100 # just a number, will be overridden in fetchDB
        self.step = 0 # interval between PDPs in RRD DB
        self.set_id = 'tcp_anomalies_in.idx0.xml'
        self.set_id = self.sanitize(set_id)
        self.filePath = self.checkFileExistence(self.set_id)

    def err_send(self, status, report='omitted'):
        if __debug__:
                self.serialize({'status':status, 'statusStr':report})
        else:
                self.serialize({'status':status})

    def serialize(self, dict_obj):
        """
        Convert received object into JSON bytes string and store it
        in ProcessingEnd.sentData,
        which gets dispatched upon raising ProcessingEnd 
        """
        try:
            assert type(dict_obj) == dict
        except AssertionError:
            dict_obj = {'status': 6, 'statusStr':'serialize(): Object is not of type dict'}
        if "dataSet" in dict_obj:
            if "status" not in dict_obj:
                dict_obj["status"] = self.status
            if "interval" not in dict_obj:
                dict_obj["interval"] = self.step
           
        # at the end (bstrToSend must be not empty):
        sentData = json.dumps(dict_obj).encode()
        if sentData.find(b"NaN") >= 0 :
            raise ProcessingEnd(sentData = sentData.replace(b"NaN",b"null"))
        else:
            raise ProcessingEnd(sentData = sentData)

    def sanitize(self, string):
        """
        Raise an exception if the symbols \,/,..,$,% are found
        in a provided string
        """
        try:
            assert type(string) == str
        except AssertionError:
            self.err_send(6,'sanitize function: assertion failed')
        if '\\' in string or '..' in string or '$' in string \
                            or '%' in string or '/' in string :
            self.err_send(3)
        else:
            return string
    
    def checkFileExistence(self, set_id):
        """
        Raise exception , if a requested DB file is not found in 
        preconfigured paths (see WorkerTstat.paths list) or has no
        permissions for reading 
        """
        for path in iter(self.paths):
            if os.access(path + set_id, os.F_OK):
                return path + set_id
        self.err_send(4)

    def fetchDB(self, stime, etime, cf, cdpToShow):
        """
        This is the handler function for requests.
        It
        1.  performs request string processing and sanitization
        2.  if DB the request is exactly the same as previous,
            given the interval between them is less than interval
            between DB PDPs or the DB file hasn't changed, a previous
            returned byte string is returned again
        3.  invokes rrdtool dump to retrieve xml DB file dump
        4.  transforms it into an ElementTree to facilitate access to
            elements and parsing
        5.  extracts all PDPs and CDPs from DB, as well as refresh interval
        6.  creates an concatenated array of tuples (time ,value), representing
            sorted data points from DB in ascending time order
        7.  applies requested time boundaries on data to extract relevant data,
            performs consolidation of data according to requested consolidation
            function (consolidation is required, if number of data point to be
            sent is bigger than requested number cdpToShow)
        8.  raises exception initialized with data to be returned to indicate
            end of processing
        """
        
        try:
            args = [stime,etime,cdpToShow]
            for val in iter(args):
                if str.isdecimal(val):
                    assert int(val) >= 0
                else:
                    raise AssertionError 
        except AssertionError:
            self.err_send(6,'fetchDB(): input fields assertion error')

        if int(cdpToShow) > 1000:
            __cdpToShow = 1000
            self.status = 1
        else:
            __cdpToShow = int(cdpToShow)
        if self.stime == int(stime) and \
        self.etime == int(etime) and \
        self.cf == cf and \
        self.cdpToShow == __cdpToShow and \
        ( time.time() - self.lastQueryTime < self.step or \
          os.stat(self.filePath) == self.fileState ):
            
            #immediate return of bstrToSend stored in previous invocation
            raise ProcessingEnd(sentData = self.bstrToSend)
            # NOTE! One should consider also to write here "err_send(5)"
            # it will cause only status of 5 being sent without data payload,
            # and, as a result, less bandwidth demands under high requests load.
            # However, the two cases must be considered: requests within time interval
            # between DB fetching incoming from different users and their web-sessions,
            # or from the same one. In the former case, the same bstrToSend must be
            # dispatched. In the latter case, err_send(5) must be invoked.
            # To differentiate these two cases, Sessions ID should be implemented along with
            # a whole mechanism of their generation, exchange and revocation
            #
            # The current approach guarantees at least data dispatching to all users,
            # so that web-browsers will always have data to plot
        
        self.stime = int(stime)
        self.etime = int(etime)
        self.cf = cf
        self.cdpToShow = __cdpToShow
            
        try:
            #try here without shell arg for security reasons, but PATH may be broken
            xml_file = subprocess.check_output(['rrdtool dump ' + self.filePath], \
                                           universal_newlines = True,\
                                           shell = True)
        except subprocess.CalledProcessError as err:
            self.err_send(6, 'rrdtool call failed. Report: ' + str(err.returncode))
            
        try:
            assert type(xml_file) == str
        except AssertionError:
            try:
                assert type(xml_file) == bytes
                # Let's assume the source is encoded as UTF-8 (for tstat it's true)
                xml_file = xml_file.decode()
            except AssertionError:
                self.err_send(6,'rrdtool dump returned type is unknown')
        
        rootElement = parse(xml_file)
        self.lastQueryTime = int(time.time())
        # db is whole DB in one array of tuples
        db = self.concatenateRRAs(rootElement)
        self.fileState = os.stat(self.filePath) 
        
        # Logic for processing requested time boundaries
        if self.etime > int(time.time()):
            self.etime = int(time.time())
        if self.stime == 0 and self.etime == 0:
            fetchedDB = db
        elif self.stime == 0:
            idx = self.find_closest_older([i[0] for i in db], self.etime)
            fetchedDB = db[:idx+2]
        elif self.etime == 0:
            idx = self.find_closest_older([i[0] for i in db], self.stime)
            fetchedDB = db[idx+1:]
        elif self.stime >= self.etime:
            fetchedDB = db[-1]
        else:
            times = [i[0] for i in db]
            idx_e = self.find_closest_older(times, self.etime)
            idx_s = self.find_closest_older(times, self.stime)
            fetchedDB = db[idx_s+1:idx_e+2]
        
        if self.cdpToShow >= len(fetchedDB):
            self.serialize({"dataSet":fetchedDB})
        else:
            self.serialize({"dataSet":self.consolidate(fetchedDB)})
        
    def consolidate(self, array):
        """
        Implements consolidation functions average (default)
        and max
        If consolidated cell has at least one non NaN value, then the cell
        takes on that value
        """

        times, vals = itertools.zip_longest(*array)
        aft = self.cdpToShow
        bef = len(vals)
        cArr = []
        if self.cf == "max":
            smplsPerSlot = bef // aft
            rest = bef % aft
            cArr.append(
                        ( times[rest + smplsPerSlot - 1],
                          max(vals[:rest + smplsPerSlot])                          
                        )
                       )
            
            for i in range(1, aft):
                cArr.append(
                            ( times[(i+1)*smplsPerSlot  + rest - 1],
                              max(vals[i*smplsPerSlot + rest:(i+1)*smplsPerSlot + rest])                              
                            )
                           )

        else:
            if self.cf != "average":
                self.status = 2
            smplsPerSlot = bef // aft
            rest = bef % aft
            
            nans = 0;
            sums = 0;
            length = len(vals[:rest + smplsPerSlot])
            for val in vals[:rest + smplsPerSlot]:
                if math.isnan(val):
                    nans = nans + 1
                else: 
                    sums = sums + val
            if nans == length:
                cArr.append(
                        ( times[rest + smplsPerSlot - 1],
                          float('nan')                          
                        )
                       )
            else:
                try:
                    assert length - nans > 0
                except AssertionError:
                    self.err_send(6,'consolidate() failed assertion, value must be positive')
                cArr.append(
                            ( times[rest + smplsPerSlot - 1],
                              sums / (length - nans)                          
                            )
                           )
                
            for i in range(1, aft):
                
                    nans = 0;
                    sums = 0;
                    length = len(vals[i*smplsPerSlot + rest:(i+1)*smplsPerSlot + rest])
                    for val in vals[i*smplsPerSlot + rest:(i+1)*smplsPerSlot + rest]:
                        if math.isnan(val):
                            nans = nans + 1
                        else: 
                            sums = sums + val
                    if nans == length:
                        cArr.append(
                                ( times[(i+1)*smplsPerSlot  + rest - 1],
                                  float('nan')                          
                                )
                               )
                    else:
                        try:
                            assert length - nans > 0
                        except AssertionError:
                            self.err_send(6,'consolidate() failed assertion, value must be positive')
                        cArr.append(
                                    ( times[(i+1)*smplsPerSlot  + rest - 1],
                                      sums / (length - nans)                          
                                    )
                                   )
                
        return cArr 
                 
    def concatenateRRAs(self, rootElDocument):
        """
        Result of this function is concatenation of all RRAs in a given DB
        The result is an array of tuples (time, value), where the first time stamp
        is the oldest one out of all RRAs. Order of time stamps is increasing.
        
        Example (only time stamps are considered):
        RRAs:   1st 2nd 3rd 4th    time   |
                40  38  34  20     flow:  |
                41  40  38  30            |
                42  42  42  40            Y
        Concatenated Array will be: [20,30,34,38,40,41,42]
        """
        rootElement = rootElDocument.find('rrd')
        step = rootElement.findtext('step') #between PDPs
        self.step = int(step) if step.isdecimal() else self.err_send(6,'Wrong parsed "step" value')
        db_arr = rootElement.findall('.//database')
        if len(db_arr) == 0:
            self.err_send(6,'RRA weren\'t found')
        
        DB_vals = [float(elem.text) for elem in db_arr[0].getiterator('v')]
        DB_tstps = [int(elem.text) for elem in db_arr[0].getiterator(ET.Comment)]
        
        #time granularity of RRAs must get coarser in top-down order - it's a main assumption
        for num in range(1, len(db_arr)):
            rra_values =  [float(elem.text) for elem in db_arr[num].getiterator('v')]
            rra_timestamps = [int(elem.text) for elem in db_arr[num].getiterator(ET.Comment)]
                                  
            # DB_tstps[0] is the oldest time stamp in the concatenated DB                                                                         
            index = self.find_closest_older(rra_timestamps, DB_tstps[0])
            
            # here insertion of an array at the beginning is performed, stupid but fast 
            DB_vals.reverse()
            rra_values.reverse()
            DB_vals.extend(rra_values[len(rra_values)-1-index:])
            DB_vals.reverse()
            
            DB_tstps.reverse()
            rra_timestamps.reverse()
            DB_tstps.extend(rra_timestamps[len(rra_timestamps)-1-index:])
            DB_tstps.reverse()    
    
        # create array of tuples to bind time,value pairs
        DB = [i for i in itertools.zip_longest(
                                        DB_tstps,
                                        DB_vals,
                                        fillvalue=0
                                       )]
        
        return DB
    
    def find_closest_older(self, arr, val):
            """
            Implementation of a binary search algorithm, the index
            of a closest smaller array value to a provided val is returned
            """    
            first = 0
            last = len(arr)
            if last == 0:
                self.err_send(6,'func find_closest_older: array is empty')
            elif arr[0] > val:
                self.err_send(6,'an useless RRA has been found in ' + self.set_id \
                         +': its time span is lower than that of finer granularity RRA')
            elif arr[-1] < val:
                self.err_send(6,'wrong format of RRA in ' + self.set_id \
                         + ': this RRA doesn\'t span time stamps\
                          of previous (finer granularity) one')
            while first < last:
                idx = first + (last - first) // 2
                if val <= arr[idx]:
                    last = idx
                else:
                    first = idx + 1
            
            return last - 1


if __name__ == '__main__':
    from wsgiref import validate
    from flup.server.fcgi import WSGIServer
    
    disp = RequestDispatcher()
    validated_app = validate.validator(disp.dispatch)
    WSGIServer(validated_app, bindAddress='/tmp/fastcgi.python.socket').run()
    
