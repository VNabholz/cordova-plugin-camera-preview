package com.cordovaplugincamerapreview;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.Log;

import org.apache.cordova.CordovaPlugin;

import java.util.HashSet;
import java.util.List;


public class MovementDetector extends CordovaPlugin implements SensorEventListener {

  protected final String TAG = getClass().getSimpleName();

  private SensorManager sensorMan;
  private Sensor accelerometer;
  private int accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM;

  private MovementDetector() {
  }

  private static MovementDetector mInstance;

  public static MovementDetector getInstance(Context context) {
    if (mInstance == null) {
      mInstance = new MovementDetector();
      mInstance.init(context);
    }
    return mInstance;
  }

  private HashSet<Listener> mListeners = new HashSet<MovementDetector.Listener>();

  private void init(Context context) {
    sensorMan = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
    accelerometer = sensorMan.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION);

  }

  public void start() {
    // Get accelerometer from sensor manager

    mOrientationRounded = 0; // Reset the value for the moment when the camera is reopened.

    List<Sensor> list = this.sensorMan.getSensorList(Sensor.TYPE_ACCELEROMETER);

    // If found, then register as listener
    if ((list != null) && (list.size() > 0)) {
      this.accelerometer = list.get(0);
      if (this.sensorMan.registerListener(this, this.accelerometer, SensorManager.SENSOR_DELAY_NORMAL)) {
        // CB-11531: Mark accuracy as 'reliable' - this is complementary to
        // setting it to 'unreliable' 'stop' method
        this.accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM;
      }

    }
  }

  public void stop() {
    try {
      sensorMan.unregisterListener(this);
      mListeners.clear();
    } catch (Exception e) {
      Log.e(TAG, e.getMessage());
    }
  }

  public void addListener(Listener listener) {
    mListeners.add(listener);
  }

  public int mOrientationDeg; //last rotation in degrees
  public int mOrientationRounded; //last orientation int from above
  private static final int _DATA_X = 0;
  private static final int _DATA_Y = 1;
  private static final int _DATA_Z = 2;
  private int ORIENTATION_UNKNOWN = -1;
  
  // Variables for orientation stabilization
  private long lastOrientationChangeTime = 0;
  private static final long ORIENTATION_CHANGE_DELAY = 300; // 300ms delay for stabilization - faster for small angles

  @Override
  public void onSensorChanged(SensorEvent event) {
    float[] values = event.values;
    int orientation = ORIENTATION_UNKNOWN;
    float X = -values[_DATA_X];
    float Y = -values[_DATA_Y];
    float Z = -values[_DATA_Z];
    float magnitude = X * X + Y * Y;
    int tempOrientRounded = 0;

    // Calculate total acceleration to determine if device is truly flat
    float totalAcceleration = (float) Math.sqrt(X * X + Y * Y + Z * Z);
    float tiltAngle = (float) Math.toDegrees(Math.acos(Math.abs(Z) / totalAcceleration));
    
    // More precise flat detection: device is flat only if tilt angle is less than 15 degrees
    boolean isDeviceFlat = tiltAngle < 15.0f;
    
    // Log detailed sensor data for debugging
    Log.d(TAG, String.format("Sensor data - X: %.2f, Y: %.2f, Z: %.2f", X, Y, Z));
    Log.d(TAG, String.format("Total acceleration: %.2f, Tilt angle: %.2f°", totalAcceleration, tiltAngle));
    Log.d(TAG, "Device flat: " + isDeviceFlat);

    // Use a more lenient threshold for orientation calculation
    // Only skip orientation calculation if device is truly flat (very small tilt angle)
    if (!isDeviceFlat) {
      float OneEightyOverPi = 57.29577957855f;
      float angle = (float) Math.atan2(-Y, X) * OneEightyOverPi;
      orientation = 90 - (int) Math.round(angle);

      // normalize to 0 - 359 range
      while (orientation >= 360) {
        orientation -= 360;
      }

      while (orientation < 0) {
        orientation += 360;
      }
    }

    //^^ thanks to google for that code
    //now we must figure out which orientation based on the degrees

    if (orientation != mOrientationDeg || isDeviceFlat) {
      mOrientationDeg = orientation;
      
      // Log raw orientation for debugging
      Log.d(TAG, "Raw sensor orientation: " + orientation + "°");
      
      //figure out actual orientation using a more adaptive approach
      if (isDeviceFlat) {
        // Device is truly flat - keep current orientation or default to portrait if none set
        tempOrientRounded = (mOrientationRounded != 0) ? mOrientationRounded : 1;
        Log.d(TAG, "Device is flat (tilt: " + String.format("%.1f", tiltAngle) + "°), keeping orientation: " + ((tempOrientRounded - 1) * 90) + "°");
      } else if (orientation == -1) {
        // Fallback case - shouldn't happen with new logic
        tempOrientRounded = (mOrientationRounded != 0) ? mOrientationRounded : 1;
        Log.d(TAG, "Unknown orientation, keeping current: " + ((tempOrientRounded - 1) * 90) + "°");
      } else {
        // Calculate the closest orientation using distance-based approach
        int[] orientationTargets = {0, 90, 180, 270}; // portrait, landscape-left, upside-down, landscape-right
        int[] orientationCodes = {1, 4, 3, 2}; // corresponding codes
        
        int closestIndex = 0;
        int minDistance = Integer.MAX_VALUE;
        
        for (int i = 0; i < orientationTargets.length; i++) {
          int target = orientationTargets[i];
          int distance = Math.min(
            Math.abs(orientation - target),
            Math.min(Math.abs(orientation - target - 360), Math.abs(orientation - target + 360))
          );
          
          if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
          }
        }
        
        // More sensitive threshold - change orientation if within 45 degrees of target
        if (minDistance <= 45) {
          tempOrientRounded = orientationCodes[closestIndex];
          Log.d(TAG, "Closest orientation: " + orientationTargets[closestIndex] + "° (distance: " + minDistance + "°)");
        } else {
          // Too far from any target, keep current orientation
          tempOrientRounded = mOrientationRounded;
          Log.d(TAG, "Orientation too ambiguous (min distance: " + minDistance + "°), keeping current: " + ((mOrientationRounded - 1) * 90) + "°");
        }
      }

      if (mOrientationRounded != tempOrientRounded) {
        // Add delay to avoid sudden changes
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastOrientationChangeTime > ORIENTATION_CHANGE_DELAY) {
          // Orientation changed, handle the change here
          mOrientationRounded = tempOrientRounded;
          lastOrientationChangeTime = currentTime;
          for (Listener listener : mListeners) {
            listener.onMotionDetected((mOrientationRounded - 1) * 90);
          }
          Log.d(TAG, "Orientation changed from " + orientation + "° (raw) to: " + ((mOrientationRounded - 1) * 90) + "° (rounded)");
        }
      }
    }
  }

  /* (non-Javadoc)
   * @see android.hardware.SensorEventListener#onAccuracyChanged(android.hardware.Sensor, int)
   */
  @Override
  public void onAccuracyChanged(Sensor sensor, int accuracy) {
    // TODO Auto-generated method stub
  }

  public interface Listener {
    void onMotionDetected(int postion);
  }
}
