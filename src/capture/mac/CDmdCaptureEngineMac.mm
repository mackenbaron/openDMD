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
#import "CDmdCaptureEngineMac.h"

#include "DmdLog.h"
#include "DmdMutex.h"

namespace opendmd {

CDmdCaptureEngineMac::CDmdCaptureEngineMac() : m_pCaptureDevice(nil) {
}

CDmdCaptureEngineMac::~CDmdCaptureEngineMac() {
    if (m_pCaptureDevice) {
        delete m_pCaptureDevice;
    }
}

DMD_RESULT CDmdCaptureEngineMac::Init() {
    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::Uninit() {
    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::StartCapture() {
    return DMD_S_OK;
}

DMD_BOOL CDmdCaptureEngineMac::IsCapturing() {
    return false;
}

DMD_RESULT CDmdCaptureEngineMac::StopCapture() {
    return DMD_S_OK;
}

DMD_RESULT CDmdCaptureEngineMac::DeliverVideoData(
        CMSampleBufferRef sampleBuffer) {
    return DMD_S_OK;
}



// public interface implementation defined at CDmdCaptureEngine.h
DMD_RESULT CreateVideoCaptureEngine(IDmdCaptureEngine **ppVideoCapEngine) {
    if (NULL == ppVideoCapEngine) {
        return DMD_S_FAIL;
    }
    CDmdCaptureEngineMac *pMacVideoCapEngine = new CDmdCaptureEngineMac();
    pMacVideoCapEngine->Init();

    *ppVideoCapEngine = (IDmdCaptureEngine *)pMacVideoCapEngine;

    return DMD_S_OK;
}

DMD_RESULT ReleaseVideoCaptureEngine(IDmdCaptureEngine **ppVideoCapEngine) {
    (*ppVideoCapEngine)->Uninit();

    ppVideoCapEngine = NULL;
    return DMD_S_OK;
}

}  // namespace opendmd
