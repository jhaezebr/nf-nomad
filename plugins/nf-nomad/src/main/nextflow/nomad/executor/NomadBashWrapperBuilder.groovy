/*
 * Copyright 2023, Stellenbosch University, South Africa
 * Copyright 2022, Center for Medical Genetics, Ghent
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package nextflow.nomad.executor


import groovy.transform.CompileStatic
import nextflow.executor.BashWrapperBuilder
import nextflow.processor.TaskRun
import nextflow.util.Escape

/**
 * Implements a BASH wrapper for tasks executed by Nomad cluster
 *
 * @author Abhinav Sharma <abhi18av@outlook.com>
 */
@CompileStatic
class NomadBashWrapperBuilder extends BashWrapperBuilder {

    NomadBashWrapperBuilder(TaskRun task) {
        super(task)
        this.headerScript = "NXF_CHDIR=${Escape.path(task.workDir)}"
    }

    /**
     * only for testing purpose -- do not use
     */
    protected NomadBashWrapperBuilder() {}

}
