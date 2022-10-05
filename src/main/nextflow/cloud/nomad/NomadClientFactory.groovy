
/*
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

package nextflow.nomad

import com.hashicorp.nomad.javasdk.NomadApiClient
import com.hashicorp.nomad.javasdk.NomadApiConfiguration
import groovy.transform.CompileStatic
import groovy.util.logging.Slf4j
import nextflow.Global
import nextflow.exception.AbortOperationException

/**
 *
 * @author matthdsm <matthias.desmet@ugent.be>
 */
@Slf4j
@CompileStatic
class NomadClientFactory {
    NomadApiConfiguration config =
        new NomadApiConfiguration.Builder()
                .setAddress("http://192.168.100.100:4646")
                .build();

    NomadApiClient apiClient = new NomadApiClient(config);
}