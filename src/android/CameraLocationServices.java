/*
       Licensed to the Apache Software Foundation (ASF) under one
       or more contributor license agreements.  See the NOTICE file
       distributed with this work for additional information
       regarding copyright ownership.  The ASF licenses this file
       to you under the Apache License, Version 2.0 (the
       "License"); you may not use this file except in compliance
       with the License.  You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing,
       software distributed under the License is distributed on an
       "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
       KIND, either express or implied.  See the License for the
       specific language governing permissions and limitations
       under the License.
 */
package com.cordovaplugincamerapreview;


import android.content.Context;
import android.location.Location;
import android.location.LocationManager;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.gson.Gson;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class CameraLocationServices implements GoogleApiClient.ConnectionCallbacks {

    private CameraLocationListener mListener;
    private boolean mWantLastLocation = false;
    private boolean mWantUpdates = false;
    private CallbackContext mCbContext;
    private GApiUtils mGApiUtils;
    private GoogleApiClient mGApiClient;
    public CordovaInterface cordova;
    public Location globalLocation;
    CallbackContext callbackContext;

    public CameraLocationServices(CordovaInterface cordova) {
        Log.d(LocationUtils.APPTAG, "CameraLocationServices");
        this.cordova = cordova;
        mGApiClient = new GoogleApiClient.Builder(cordova.getActivity())
                .addApi(LocationServices.API).addConnectionCallbacks(this)
                .addOnConnectionFailedListener(getGApiUtils()).build();
    }

    @Override
    public void onConnected(Bundle bundle) {
        Log.d(LocationUtils.APPTAG, "Location Services connected");
        if (mWantLastLocation) {
            mWantLastLocation = false;
            getLastLocation();
        }

        if (mListener != null && mWantUpdates) {
            mWantUpdates = false;
            mListener.start();
        }

    }

    @Override
    public void onConnectionSuspended(int i) {
        Log.i(LocationUtils.APPTAG, "GoogleApiClient connection has been suspend");
    }


    /**
     * Executes the request and returns PluginResult.
     *
     * @param callbackContext The callback id used when calling back into JavaScript.
     * @return True if the action was valid, or false if not.
     */
    public boolean getLocation(final CallbackContext callbackContext) {
        Log.d(LocationUtils.APPTAG, "getLocation");
        this.callbackContext = callbackContext;


        if (isGPSdisabled()) {
            // There it was the photo save.
            Log.d(LocationUtils.APPTAG, "The isGPSdisabled is: " + String.valueOf(isGPSdisabled()));
        } else {
            if (getGApiUtils().servicesConnected()) {
                if (!mGApiClient.isConnected() && !mGApiClient.isConnecting()) {
                    mGApiClient.connect();
                }

                if (mGApiClient.isConnected()) {
                    getLastLocation(callbackContext);
                } else {
                    setWantLastLocation(callbackContext);
                }

            }
        }

        return true;
    }


    /**
     * Called when the activity is to be shut down. Stop listener.
     */
    public void onDestroy() {
        if (mListener != null) {
            mListener.destroy();
        }

        if (mGApiClient.isConnected() || mGApiClient.isConnecting()) {
            // After disconnect() is called, the client is considered "dead".
            mGApiClient.disconnect();
        }
    }

    public void completeDestroy() {
        clearWatch("1");
        onDestroy();
        mInstance = null;
        mListener = null;

    }

    /**
     * Called when the view navigates. Stop the listeners.
     */
    public void onReset() {
        this.onDestroy();
    }


    /**
     * Location failed. Send error back to JavaScript.
     *
     * @param code The error code
     * @param msg  The error message
     */
    public void fail(int code, String msg, CallbackContext callbackContext, boolean keepCallback) {
        Log.e(LocationUtils.APPTAG, "The location service failed!");
    }

    private boolean isGPSdisabled() {
        boolean gps_enabled;

        LocationManager lm = (LocationManager) this.cordova.getActivity().getSystemService(Context.LOCATION_SERVICE);

        try {
            gps_enabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER);
        } catch (Exception ex) {
            ex.printStackTrace();
            gps_enabled = false;
        }

        return !gps_enabled;
    }

    private void getLastLocation() {
        getLastLocation(mCbContext);
        mCbContext = null;
    }

    private void getLastLocation(CallbackContext callbackContext) {
        int maximumAge = 100000;

        try {

            Location last = LocationServices.FusedLocationApi.getLastLocation(mGApiClient);

            // Check if we can use lastKnownLocation to get a quick reading and use
            // less battery

            if (last != null && (System.currentTimeMillis() - last.getTime()) <= maximumAge) {
                getGPSData(last);
            } else {
                getCurrentLocation(callbackContext, 5000);
            }

        } catch (Exception e) {
            getCurrentLocation(callbackContext, 5000);
            e.printStackTrace();
        }

    }

    private void setWantLastLocation(CallbackContext callbackContext) {
        mCbContext = callbackContext;
        mWantLastLocation = true;
    }

    private void getCurrentLocation(CallbackContext callbackContext, int timeout) {
        getListener().addCallback(callbackContext, timeout);
    }

    private void clearWatch(String id) {
        getListener().clearWatch(id);
    }

    private void addWatch(String timerId, CallbackContext callbackContext) {
        getListener().addWatch(timerId, callbackContext);
    }

    private CameraLocationListener getListener() {
        if (mListener == null) {
            mListener = new CameraLocationListener(mGApiClient, this, LocationUtils.APPTAG);
        }
        return mListener;
    }

    private GApiUtils getGApiUtils() {
        if (mGApiUtils == null) {
            mGApiUtils = new GApiUtils(cordova);
        }
        return mGApiUtils;
    }

    /**
     * The code GPS implementation.
     * This code should be improved.
     **/


    public static String getDms(double val) {
        double valDeg;
        double valMin;
        double valSec;
        String result;

        val = Math.abs(val);

        valDeg = Math.floor(val);
        result = String.valueOf((int) valDeg) + "/1,";

        valMin = Math.floor((val - valDeg) * 60);
        result += String.valueOf((int) valMin) + "/1,";

        valSec = Math.round((val - valDeg - valMin / 60) * 3600 * 10000);
        result += String.valueOf((int) valSec) + "/10000";

        return result;
    }

    private static CameraLocationServices mInstance;
    private List<Listener> listeners = new ArrayList<Listener>();

    public static CameraLocationServices getInstance(CordovaInterface cordova, CallbackContext context) {
        if (mInstance == null) {
            mInstance = new CameraLocationServices(cordova);
            mInstance.getLocation(context);
        }

        return mInstance;
    }

    public void addListener(Listener toAdd) {
        listeners.add(toAdd);
    }

    public void getGPSData(Location location) {
        globalLocation = location;

        final int priority = LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY;
        final long interval = LocationUtils.UPDATE_INTERVAL_IN_MILLISECONDS;
        final long fastInterval = LocationUtils.FAST_INTERVAL_CEILING_IN_MILLISECONDS;

        getListener().setLocationRequestParams(priority, interval, fastInterval);
        mWantUpdates = true;
        addWatch("1", callbackContext);

        for (Listener hl : listeners) {
            hl.getCoordonates(location);
        }
    }

    public interface Listener {
        void getCoordonates(Location location);
    }
}
