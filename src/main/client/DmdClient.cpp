/*
 ============================================================================
 * Name        : DmdClient.cpp
 * Author      : weizhenwei, <weizhenwei1988@gmail.com>
 * Date        : 2015.11.24
 *
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
 * Description : main entry of client program;
 ============================================================================
 */

#include <pthread.h>
#include <unistd.h>

#include "DmdLog.h"
#include "DmdSignal.h"
#include "CDmdCaptureEngine.h"
#include "CDmdCaptureThread.h"

#include "thread/DmdThreadManager.h"
#include "client/DmdClientThreads.h"


#include "DmdClient.h"

namespace opendmd {

DmdClient::DmdClient() {
    Init();
}
DmdClient::~DmdClient() {
    UnInit();
}

DMD_RESULT DmdClient::Init() {
    m_pCaptureEngine = NULL;
    CreateVideoCaptureEngine(&m_pCaptureEngine);
    if (nullptr == m_pCaptureEngine) {
        DMD_LOG_ERROR("DmdClient::Init(), "
                      << ", CreateVideoCaptureEngine failed");
        return DMD_S_FAIL;
    }

    return DMD_S_OK;
}

DMD_RESULT DmdClient::UnInit() {
    if (m_pCaptureEngine) {
        ReleaseVideoCaptureEngine(&m_pCaptureEngine);
        m_pCaptureEngine = NULL;
    }

    return DMD_S_OK;
}

DMD_RESULT DmdClient::InitGlobalThreadManager() {
    g_ThreadManager = DmdThreadManager::singleton();
    if (NULL == g_ThreadManager) {
        DMD_LOG_ERROR("InitGlobal(), "
                      << "init g_ThreadManager failed");
        return DMD_S_FAIL;
    }

    return DMD_S_OK;
}

void DmdClient::InitSignal() {
    int ret = -1;
    DmdRegisterDefaultSignal();

    sigset_t blockedSignalSet;
    sigemptyset(&blockedSignalSet);
    sigaddset(&blockedSignalSet, SIGINT);  // block SIGINT for sigwait;
    if (0 != (ret = pthread_sigmask(SIG_BLOCK, &blockedSignalSet, NULL))) {
        DMD_LOG_WARNING("initSignal(), call pthread_sigmask error:"
                        << ret);
    }
}

void DmdClient::CreateAndSpawnThreads() {
    // create signal manager thread;
    DmdThreadType eSignalManagerThread = DMD_THREAD_SIGMGR;
    DmdThreadRoutine pSigMgrRoutine = SignalManagerThreadRoutine;
    g_ThreadManager->addThread(eSignalManagerThread, pSigMgrRoutine, nullptr);

    // create capture thread;
    DmdThreadType eCaptureThread = DMD_THREAD_CAPTURE;
    DmdThreadRoutine pCaptureRoutine = CaptureThreadRoutine;
    g_ThreadManager->addThread(eCaptureThread, pCaptureRoutine,
            m_pCaptureEngine);

    // spawn all working thread;
    g_ThreadManager->spawnAllThreads();
}

void DmdClient::ExitAndCleanThreads() {
    // send signal to all threads;
    g_ThreadManager->killAllThreads();

    // clean all working thread;
    g_ThreadManager->cleanAllThreads();
}


int DmdClient::DmdClientMain(int argc, char *argv[]) {
    DMD_LOG_INFO("At the beginning of client_main function");

    InitGlobalThreadManager();
    InitSignal();

    if (1) {
        // create and spawn threads;
        CreateAndSpawnThreads();

        while (g_bMainThreadRunning) {
            sleep(1);
            DMD_LOG_INFO("client_main(), main thread is running");
        }

        uint32_t usleeps = 500000;  // sleep 0.5 s;
        usleep(usleeps);  // wait all threads exit;

        // exit and clean threads;
        DMD_LOG_INFO("client_main(), before cleaning threads");
        ExitAndCleanThreads();
    }

    DMD_LOG_INFO("client_main(), main thread is exiting");

    return DMD_S_OK;
}

}  // namespace opendmd

