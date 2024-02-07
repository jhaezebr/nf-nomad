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

import groovy.json.JsonBuilder
import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import groovy.util.logging.Slf4j
import nextflow.k8s.model.PodEnv
import nextflow.processor.TaskRun
import nextflow.util.MemoryUnit

import java.nio.file.Path
import java.util.concurrent.atomic.AtomicInteger

/**
 * Object build for a Nomad job specification
 *
 * @author Abhinav Sharma <abhi18av@outlook.com>
 */
@CompileStatic
@Slf4j
class NomadJobBuilder {

    static enum MetaType {
        LABEL, META
    }

    static enum SegmentType {
        PREFIX(253),
        NAME(63),
        VALUE(63)

        private final int maxSize;

        SegmentType(int maxSize) {
            this.maxSize = maxSize;
        }
    }

    String jobName

    String taskGroupName

    String taskName

    String restart

    Map<String,String> envVars = [:]

    Map<String,String> labels = [:]

    String imageName

    List<String> command = []

    List<String> args = new ArrayList<>()

    String namespace

    String workDir

    Integer cpus

    String memory

    String disk

    String serviceAccount

    boolean privileged

    Map<String, ?> resourcesLimits

    NomadJobBuilder withEnv(String name, String value ) {
        this.envVars.put(name, value)
        return this
    }

    NomadJobBuilder withEnv( Map envs ) {
        this.envVars.putAll(envs)
        return this
    }

    NomadJobBuilder withLabel( String name, String value ) {
        this.labels.put(name, value)
        return this
    }

    NomadJobBuilder withLabels(Map labels) {
        this.labels.putAll(labels)
        return this
    }

    NomadJobBuilder withJobName(String name) {
        this.jobName = name
        this.taskGroupName = "${jobName}_taskgroup"
        this.taskName = "${jobName}_task"
        return this
    }

    NomadJobBuilder withImageName(String name) {
        this.imageName = name
        return this
    }

    NomadJobBuilder withWorkDir(String path) {
        this.workDir = path
        return this
    }

    NomadJobBuilder withWorkDir(Path path) {
        this.workDir = path.toString()
        return this
    }

    NomadJobBuilder withNamespace(String name) {
        this.namespace = name
        return this
    }

    NomadJobBuilder withServiceAccount(String name) {
        this.serviceAccount = name
        return this
    }

    NomadJobBuilder withCommand(cmd) {
        if (cmd == null) return this
        assert cmd instanceof List || cmd instanceof CharSequence, "Missing or invalid Nomad command parameter: $cmd"
        this.command = cmd instanceof List ? cmd : ['/bin/bash', '-c', cmd.toString()]
        return this
    }

    NomadJobBuilder withArgs(args) {
        if (args == null) return this
        assert args instanceof List || args instanceof CharSequence, "Missing or invalid Nomad args parameter: $args"
        this.args = args instanceof List ? args : ['/bin/bash', '-c', args.toString()]
        return this
    }

    NomadJobBuilder withCpus(Integer cpus) {
        this.cpus = cpus
        return this
    }

    NomadJobBuilder withMemory(String mem) {
        this.memory = mem
        return this
    }

    NomadJobBuilder withMemory(MemoryUnit mem) {
        this.memory = "${mem.mega}Mi".toString()
        return this
    }

    NomadJobBuilder withDisk(String disk) {
        this.disk = disk
        return this
    }

    NomadJobBuilder withDisk(MemoryUnit disk) {
        this.disk = "${disk.mega}Mi".toString()
        return this
    }

    NomadJobBuilder withPrivileged(boolean value) {
        this.privileged = value
        return this
    }

    NomadJobBuilder withResourcesLimits(Map<String, ?> limits) {
        this.resourcesLimits = limits
        return this
    }

    Map build() {
        assert this.jobName, 'Missing Nomad jobName parameter'
        assert this.imageName, 'Missing Nomad imageName parameter'
        assert this.command || this.args, 'Missing Nomad command parameter'

        final restart = this.restart ?: 'Never'

        final metadata = new LinkedHashMap<String, Object>()
        metadata.name = jobName
        metadata.namespace = namespace ?: 'default'

        final container = [name: this.jobName, image: this.imageName]
        if (this.command)
            container.command = this.command
        if (this.args)
            container.args = args

        if (this.workDir)
            container.put('workingDir', workDir)

        final secContext = new LinkedHashMap(10)
        if (privileged) {
            // note: privileged flag needs to be defined in the *container* securityContext
            // not the 'spec' securityContext (see below)
            secContext.privileged = true
        }

        final job = [
            Job: [
                ID         : jobName,
                Name       : jobName,
                Type       : 'batch',
                Constraints: [[
                                  LTarget: "\${node.unique.name}",
                                  RTarget: "nomad02",
                                  Operand: "="
                              ]],
                Datacenters: ["sun-nomadlab"],
                TaskGroups : [
                    [Name : taskGroupName,
                     Tasks: [[Name     : taskName,
                              Driver   : "docker",
                              Resources: [Cores   : cpus,
                                          MemoryMB: memory],
                              Env: envVars,
                              Config   : [
                                  privileged: privileged,
                                  args      : args,
//                                  command   : "bash",
                                  image     : container.image
                              ]]]]
                ]]
        ]

        // add resources
        if (this.cpus) {
            container.resources = addCpuResources(this.cpus, container.resources as Map)
        }

        if (this.memory) {
            container.resources = addMemoryResources(this.memory, container.resources as Map)
        }

        if (this.resourcesLimits) {
            container.resources = addResourcesLimits(this.resourcesLimits, container.resources as Map)
        }

        return job
    }


    String buildAsJson() {
        final job = build()

        return new JsonBuilder(job)
    }

    @PackageScope
    Map addResourcesLimits(Map limits, Map result) {
        if (result == null)
            result = new LinkedHashMap(10)

        final limits0 = result.limits as Map ?: new LinkedHashMap(10)
        limits0.putAll(limits)
        result.limits = limits0

        return result
    }

    @PackageScope
    Map addCpuResources(Integer cpus, Map res) {
        if (res == null)
            res = [:]

        final req = res.requests as Map ?: new LinkedHashMap<>(10)
        req.cpu = cpus
        res.requests = req

        return res
    }

    @PackageScope
    Map addMemoryResources(String memory, Map res) {
        if (res == null)
            res = new LinkedHashMap(10)

        final req = res.requests as Map ?: new LinkedHashMap(10)
        req.memory = memory
        res.requests = req

        final lim = res.limits as Map ?: new LinkedHashMap(10)
        lim.memory = memory
        res.limits = lim

        return res
    }

    protected Map sanitize(Map map, MetaType kind) {
        final result = new HashMap(map.size())
        for (Map.Entry entry : map) {
            final key = sanitizeKey(entry.key as String, kind)
            final value = (kind == MetaType.LABEL)
                ? sanitizeValue(entry.value, kind, SegmentType.VALUE)
                : entry.value

            result.put(key, value)
        }
        return result
    }

    protected String sanitizeKey(String value, MetaType kind) {
        final parts = value.tokenize('/')

        if (parts.size() == 2) {
            return "${sanitizeValue(parts[0], kind, SegmentType.PREFIX)}/${sanitizeValue(parts[1], kind, SegmentType.NAME)}"
        }
        if (parts.size() == 1) {
            return sanitizeValue(parts[0], kind, SegmentType.NAME)
        } else {
            throw new IllegalArgumentException("Invalid key in pod ${kind.toString().toLowerCase()} -- Key can only contain exactly one '/' character")
        }
    }


    /**
     * Sanitize a string value to contain only alphanumeric characters, '-', '_' or '.',
     * and to start and end with an alphanumeric character.
     */
    protected String sanitizeValue(value, MetaType kind, SegmentType segment) {
        def str = String.valueOf(value)
        if (str.length() > segment.maxSize) {
            log.debug "K8s $kind $segment exceeds allowed size: $segment.maxSize -- offending str=$str"
            str = str.substring(0, segment.maxSize)
        }
        str = str.replaceAll(/[^a-zA-Z0-9\.\_\-]+/, '_')
        str = str.replaceAll(/^[^a-zA-Z0-9]+/, '')
        str = str.replaceAll(/[^a-zA-Z0-9]+$/, '')
        return str
    }

}
