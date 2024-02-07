/*
 * Copyright 2013-2023, Seqera Labs
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

package nextflow.nomad.model

import groovy.transform.CompileStatic
import groovy.transform.EqualsAndHashCode
import groovy.transform.PackageScope
import groovy.transform.ToString
import nextflow.nomad.model.*

/**
 * Model Nomad job options such as environment variables and meta fields.
 *
 * @author Abhinav Sharma <abhi18av@outlook.com>
 */
@CompileStatic
@ToString(includeNames = true)
@EqualsAndHashCode(includeFields = true)
class NomadJobOptions {

    private Collection<NomadTaskEnv> envVars

    private Map<String,String> meta = [:]


    Map<String,String> getMeta() { meta }

    NomadJobOptions( List<Map> options=null ) {
        int size = options ? options.size() : 0
        envVars = new HashSet<>(size)
        init(options)
    }

    @PackageScope void init(List<Map> options) {
        if( !options ) return
        for( Map entry : options ) {
            create(entry)
        }
    }

    @PackageScope void create(Map<String,String> entry) {
        if( entry.env && entry.value ) {
            envVars << NomadTaskEnv.value(entry.env, entry.value)
        }
        else
            throw new IllegalArgumentException("Unknown Nomad job options: $entry")
    }


}
