# Build with Metalsmith
metalsmith = require('metalsmith')
path = require("path")

set_metadata_defaults = (files, metalsmith, done) ->
    # Simple way to apply metadata defaults
    for k, v of files
        # Autotoc defaults to true
        # Set domain templates
        if 'topics' in v.collection
            files[k].layout = 'topic.pug' if files[k].layout == undefined
            files[k].autotoc = false if files[k].autotoc == undefined
            files[k].tutorials = []
            files[k].slides = []
        else if 'tutorials' in v.collection
            files[k].layout = 'default.pug' if files[k].layout == undefined
            files[k].autotoc = false if files[k].autotoc == undefined
            # Add parent/child links for topic
            parent_topic = k.split('/')[0]
            if files[path.join(parent_topic, 'metadata.md')]
                files[k].parent_topic = files[path.join(parent_topic, 'metadata.md')]
                # This is hacky, consolidate logic eventually
                files[path.join(parent_topic, 'metadata.md')].tutorials = files[path.join(parent_topic, 'metadata.md')].tutorials || []
                files[path.join(parent_topic, 'metadata.md')].tutorials.push(files[k])
        else if 'topic_slides' in v.collection
            files[k].layout = 'introduction_slides.pug' if files[k].layout == undefined
            files[k].autotoc = false if files[k].autotoc == undefined
            # Add parent/child links for topic
            parent_topic = k.split('/')[0]
            if files[path.join(parent_topic, 'metadata.md')]
                files[k].parent_topic = files[path.join(parent_topic, 'metadata.md')]
                files[path.join(parent_topic, 'metadata.md')].slides = files[path.join(parent_topic, 'metadata.md')].slides || []
                files[path.join(parent_topic, 'metadata.md')].slides.push(files[k])
        else if 'slides' in v.collection
            files[k].layout = 'introduction_slides.pug' if files[k].layout == undefined
            files[k].autotoc = false if files[k].autotoc == undefined
        else
            files[k].autotoc = true if files[k].autotoc == undefined
    done()

# Extend `marked.Renderer` to increase all heading levels by 1 since we reserve
# h1 for the page title. Will be passed to `metalsmith-markdown` plugin.
marked = require("marked")
class Renderer extends marked.Renderer
    heading: ( text, level, raw ) =>
        super( text, level + 1, raw )
    table: (header, body) =>
        return """<table class="table table-striped">
                <thead>
                #{header}
                </thead>
                <tbody>
                #{body}
                </tbody>
                </table>"""
    image: (href, title, text) =>
      out = '<img class="img-responsive" src="' + href + '" alt="' + text + '"'
      if title
          out += ' title="' + title + '"'
      out += '/>'
      return out

timer = require( "metalsmith-timer" )

ms = metalsmith(__dirname)
    .source('topics')
    .use require('metalsmith-metadata')
        site: "_config.yaml"
    .use timer 'metalsmith-metadata'
    .use require('metalsmith-collections')
        topics:
            pattern: "*/metadata.md"
        tutorials:
            pattern: "*/tutorials/*/tutorial.md"
        tutorial_slides:
            pattern: "*/tutorials/*/slides/slides.md"
        topic_slides:
            pattern: "*/slides/index.md"
    .use set_metadata_defaults
    .use timer 'set_metadata_defaults'
    .use timer 'metalsmith-collections'
    .use require('metalsmith-markdown')
        gfm: true
        renderer: new Renderer()
    .use timer 'metalsmith-markdown'
    .use require('metalsmith-autotoc')
        selector: "h2, h3, h4"
    .use timer 'metalsmith-autotoc'
    .use require('metalsmith-alias')()
    .use timer 'metalsmith-alias'
    .use require('metalsmith-filepath')
        absolute: true
        permalinks: true
    .use timer 'metalsmith-filepath'
    .use require('metalsmith-layouts')
        engine: "pug"
        cache: true
        default: "default.pug"
        pattern: "**/*.html"
        helpers:
            moment: require('moment')
            marked: require('marked')
            _: require('lodash')
    .use timer 'metalsmith-layouts'
    .use require('metalsmith-assets')
        source: 'assets'
        destination: ''
    .use timer 'metalsmith-assets'
    .use require('metalsmith-less')()
    .use timer 'metalsmith-less'

argv = require('minimist')(process.argv.slice(2))

if argv['serve']
    ms.use( require('metalsmith-serve')( { port: 8080 } ) )

if argv['check']
    ms.use require('metalsmith-broken-link-checker')
        allowRedirects: true
        warn: true

ms.build (e) ->
    if e
        throw e
    else
        console.log("Done")
