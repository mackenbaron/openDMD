/*
 ============================================================================
 Name        : CDmdCaptureEngineMac.cpp
 Author      : weizhenwei, <weizhenwei1988@gmail.com>
 Date           :2015.07.14
 Copyright   :
 * Copyright (c) 2015, weizhenwei
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * * Neither the name of the {organization} nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 Description : implementation file of capture engine on mac platform.
 ============================================================================
 */

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVCaptureSession.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSString.h>
#import <CoreVideo/CVPixelBuffer.h>

#import <string.h>
#import "CDmdCaptureEngineMac.h"

#include "DmdLog.h"
#include "DmdMutex.h"
#include "IDmdDatatype.h"

namespace opendmd {

CDmdCaptureEngineMac::CDmdCaptureEngineMac() : m_pVideoCapSession(nil) {
    memset(&m_capVideoFormat, 0, sizeof(m_capVideoFormat));
    memset(&m_capSessionFormat, 0, sizeof(m_capSessionFormat));
}

CDmdCaptureEngineMac::~CDmdCaptureEngineMac() {
    Uninit();
}


// setup AVCapSession paramters;
DMD_RESULT CDmdCaptureEngineMac::setupAVCaptureDevice() {
    DMD_CHECK_NOTNULL(m_capVideoFormat.sVideoDevice);
    NSString *capDeviceID = [NSString stringWithUTF8String:
        m_capVideoFormat.sVideoDevice];
    m_capSessionFormat.capDevice =
        [AVCaptureDevice deviceWithUniqueID:capDeviceID];
    if (m_capSessionFormat.capDevice == nil) {
        DMD_LOG_FATAL("CDmdCaptureEngineMac::setupAVCaptureDevice(), "
                << "failed to create AVCaptureDevice.");
        return DMD_S_FAIL;
    }

    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::setupAVCaptureDeviceFormat() { 
    bool bDefault = false;
    AVCaptureDeviceFormat *defaultFormat = nil;
    NSString *defaultStrFormat = @"Y'CbCr 4:2:0 - 420v, 1280 x 720";
    for ( AVCaptureDeviceFormat *format
            in [m_capSessionFormat.capDevice formats] ) {
        NSString *formatName =
            (NSString *)CMFormatDescriptionGetExtension(
                    [format formatDescription],
                    kCMFormatDescriptionExtension_FormatName);
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(
                (CMVideoFormatDescriptionRef)[format formatDescription]);
        NSString *videoformat = [NSString stringWithFormat:@"%@, %d x %d",
                                 formatName, dimensions.width,
                                 dimensions.height];
        if (!bDefault && [videoformat isEqualToString:defaultStrFormat]) {
            bDefault = true;
            defaultFormat = format;
        }
    }

    // set default video format;
    if (bDefault) {
        m_capSessionFormat.capFormat = defaultFormat;
    }

    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::setupAVCaptureSessionPreset() {
    NSArray *arrayPresets = [NSArray arrayWithObjects:
                             AVCaptureSessionPresetLow,
                             AVCaptureSessionPresetMedium,
                             AVCaptureSessionPresetHigh,
                             AVCaptureSessionPreset320x240,
                             AVCaptureSessionPreset352x288,
                             AVCaptureSessionPreset640x480,
                             AVCaptureSessionPreset960x540,
                             AVCaptureSessionPreset1280x720,
                             AVCaptureSessionPresetPhoto,
                             nil];
    for (NSString *sessionPreset in arrayPresets) {
        if ([m_capSessionFormat.capDevice
                supportsAVCaptureSessionPreset:sessionPreset]) {
            m_capSessionFormat.capSessionPreset = sessionPreset;
        }
    }
    if (m_capSessionFormat.capSessionPreset == nil) {
        DMD_LOG_FATAL("CDmdCaptureEngineMac::setupAVCaptureSessionPreset(), "
                      "no supported session preset available!");
        return DMD_S_FAIL;
    }

    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::setupAVCaptureSessionFPS() {
    float fMinFPS = 0, fMaxFPS = 0.0f;
    NSArray *ranges = [m_capSessionFormat.capFormat
        videoSupportedFrameRateRanges];
    if (ranges == nil || [ranges count] <= 0) {
        DMD_LOG_FATAL("CDmdCaptureEngineMac::setupAVCaptureSessionFPS(), "
                      << "m_capSessionFormat.capFormat "
                      << "has no effective AVFrameRageRanges.");
        return DMD_S_FAIL;
    }

    AVFrameRateRange *firstRange = [ranges firstObject];
    fMinFPS = [firstRange minFrameRate];
    fMaxFPS = [firstRange maxFrameRate];
    for (int i = 1; i < [ranges count]; i++) {
        AVFrameRateRange *range = [ranges objectAtIndex:i];
        if (fMaxFPS < [range maxFrameRate]) {
            fMaxFPS = [range maxFrameRate];
        }
        if (fMinFPS > [range minFrameRate]) {
            fMinFPS = [range minFrameRate];
        }
    }

    m_capSessionFormat.capFPS = fMaxFPS;

    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::setupAVCaptureSession() {
    DMD_RESULT ret =setupAVCaptureDevice();
    if (ret != DMD_S_OK) {
        return ret;
    }
    ret = setupAVCaptureDeviceFormat();
    if (ret != DMD_S_OK) {
        return ret;
    }
    ret = setupAVCaptureSessionPreset();
    if (ret != DMD_S_OK) {
        return ret;
    }
    ret = setupAVCaptureSessionFPS();
    if (ret != DMD_S_OK) {
        return ret;
    }
    
    return ret;
}

DMD_RESULT CDmdCaptureEngineMac::Init(DmdCaptureVideoFormat& capVideoFormat) {
    DMD_LOG_INFO("CDmdCaptureEngineMac::Init()"
            ", capVideoFormat.eVideoType = " << capVideoFormat.eVideoType
            << ", capVideoFormat.iWidth = " << capVideoFormat.iWidth
            << ", capVideoFormat.iHeight = " << capVideoFormat.iHeight
            << ", capVideoFormat.fFrameRate = " << capVideoFormat.fFrameRate
            << ", capVideoFormat.sVideoDevice = "
            << capVideoFormat.sVideoDevice);
    memcpy(&m_capVideoFormat, &capVideoFormat, sizeof(capVideoFormat));

    DMD_RESULT ret = DMD_S_OK;
    ret = setupAVCaptureSession();
    if (ret != DMD_S_OK) {
        return ret;
    }

    if (nil == m_pVideoCapSession) {
        m_pVideoCapSession = [[CDmdAVVideoCapSession alloc] init];
    }
    if (nil == m_pVideoCapSession) {
        DMD_LOG_FATAL("CDmdCaptureEngineMac::init(), "
                << "couldn't init CDmdAVVideoCapSession.");
        return DMD_S_FAIL;
    }

    [m_pVideoCapSession setSink:this];
    [m_pVideoCapSession setCapSessionFormat:m_capSessionFormat];

    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::Uninit() {
    StopCapture();
    [m_pVideoCapSession setSink:NULL];
    [m_pVideoCapSession release];
    m_pVideoCapSession = NULL;

    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::StartCapture() {
    if (YES == [m_pVideoCapSession isRunning]) {
        DMD_LOG_ERROR("CDmdCaptureEngineMac::StartCapture(), "
                      << "CDmdAVVideoCapSession is already running.");
        return DMD_S_FAIL;
    }

    if ([m_pVideoCapSession startRun:m_capSessionFormat] != DMD_S_OK) {
        DMD_LOG_ERROR("CDmdCaptureEngineMac::StartCapture(), "
                      << "AVCaptureSession start failed!");
        return DMD_S_FAIL;
    }

    return DMD_S_OK;
}

DMD_BOOL CDmdCaptureEngineMac::IsCapturing() {
    return [m_pVideoCapSession isRunning];
}

DMD_RESULT CDmdCaptureEngineMac::StopCapture() {
    return [m_pVideoCapSession stopRun];
    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::DeliverVideoData(
        CMSampleBufferRef sampleBuffer) {
    CVImageBufferRef imageBuffer =
    CMSampleBufferGetImageBuffer(sampleBuffer);
    DmdVideoRawData packet;
    memset(&packet, 0, sizeof(packet));
    if (kCVReturnSuccess == CVPixelBufferLockBaseAddress(imageBuffer, 0)) {
        if (DMD_S_OK == CVImageBuffer2VideoRawPacket(imageBuffer, packet)) {
            // DeliverVideoData(&packet);
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }

    return DMD_S_OK;
}

DMD_RESULT CVImageBuffer2VideoRawPacket(CVImageBufferRef imageBuffer,
        DmdVideoRawData& packet) {
    packet.ulRotation = 0;
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    packet.fmtVideoFormat.eVideoType = DmdI420;
    packet.fmtVideoFormat.iWidth = CVPixelBufferGetWidth(imageBuffer);
    packet.fmtVideoFormat.iHeight = CVPixelBufferGetHeight(imageBuffer);
    packet.fmtVideoFormat.fFrameRate = 0;
    packet.fmtVideoFormat.ulTimestamp = [[NSDate date] timeIntervalSince1970];
    packet.ulPlaneCount = CVPixelBufferGetPlaneCount(imageBuffer);
    if (kCVPixelFormatType_422YpCbCr8_yuvs == pixelFormat) {
        packet.fmtVideoFormat.eVideoType = DmdYV12;
        packet.pSrcData[0] =
            (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
        packet.ulDataLen = CVPixelBufferGetBytesPerRow(imageBuffer)
            * packet.fmtVideoFormat.iHeight;
    } else if (kCVPixelFormatType_422YpCbCr8 == pixelFormat) {
        packet.fmtVideoFormat.eVideoType = DmdYUY2;
        packet.pSrcData[0] =
            (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
        packet.ulDataLen = CVPixelBufferGetBytesPerRow(imageBuffer)
            * packet.fmtVideoFormat.iHeight;
    } else if (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            == pixelFormat) { // NV12 actually;
        for (int i = 0; i < packet.ulPlaneCount; i++) {
            unsigned char *pPlane = nil;
            pPlane = (unsigned char *)
                CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
            packet.pSrcData[i] = pPlane;
            size_t bytesPerRow = 0;
            bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i);
            packet.ulSrcStride[i] = bytesPerRow;
            size_t height = 0;
            height = CVPixelBufferGetHeightOfPlane(imageBuffer, i);
            packet.ulSrcDatalen[i] = bytesPerRow * height;
            packet.ulDataLen += packet.ulSrcDatalen[i];
        }
    } else {
        packet.fmtVideoFormat.eVideoType = DmdUnknown;
    }

    return DMD_S_OK;
}



// public interface implementation defined at CDmdCaptureEngine.h
const char *GetDeviceName() {
    static char deviceName[uiDeviceNameLength];

    AVCaptureDevice *device =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (nil == device) {
        DMD_LOG_ERROR("GetDeviceName(), could not get video device");
        return NULL;
    }

    const char *pDeviceName = [[device uniqueID] UTF8String];
    if (strlen(pDeviceName) > uiDeviceNameLength) {
        DMD_LOG_ERROR("GetDeviceName, video device name length > 256");
        return NULL;
    }

    strncpy(deviceName, pDeviceName, strlen(pDeviceName));

    return deviceName;
}

DMD_RESULT CreateVideoCaptureEngine(IDmdCaptureEngine **ppVideoCapEngine) {
    if (NULL == ppVideoCapEngine) {
        return DMD_S_FAIL;
    }
    CDmdCaptureEngineMac *pMacVideoCapEngine = new CDmdCaptureEngineMac();
    DMD_CHECK_NOTNULL(pMacVideoCapEngine);
    *ppVideoCapEngine = (IDmdCaptureEngine *)pMacVideoCapEngine;

    return DMD_S_OK;
}

DMD_RESULT ReleaseVideoCaptureEngine(IDmdCaptureEngine **ppVideoCapEngine) {
    (*ppVideoCapEngine)->Uninit();
    delete (*ppVideoCapEngine);

    ppVideoCapEngine = NULL;
    return DMD_S_OK;
}

}  // namespace opendmd

