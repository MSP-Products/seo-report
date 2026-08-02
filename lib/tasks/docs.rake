# Verifies the documentation in docs/ still holds together. Pure file checks —
# no Rails environment, so this runs fast and needs no database.
#
# The three checks mirror what the documentation convention promises
# (docs/README.md): every source file is findable from a document, every link
# resolves, and every path a Key files table names actually exists. That last
# one matters most — the "grep docs/ for the file you changed" rule is only
# true while those tables are accurate.
namespace :docs do
  DOCS_DIR = "docs".freeze

  # Stock Rails files and known cruft. Anything listed here is deliberately
  # exempt; docs/reference/data-model.md explains why for each.
  UNDOCUMENTED_ALLOWED = %w[
    app/models/application_record.rb
    app/jobs/application_job.rb
    app/mailers/application_mailer.rb
    app/javascript/application.js
    app/javascript/controllers/application.js
    app/javascript/controllers/index.js
    app/views/layouts/mailer.html.erb
    app/views/layouts/mailer.text.erb
  ].freeze

  desc "Find source files not mentioned in any document"
  task :coverage do
    corpus = docs_corpus
    missing = source_files.reject { |path| UNDOCUMENTED_ALLOWED.include?(path) || corpus.include?(path) }

    report("coverage", missing.map { |path| "#{path} is not named in any document" })
  end

  desc "Find links in docs/ that point nowhere"
  task :links do
    problems = markdown_files.flat_map { |file| broken_links_in(file) }

    report("links", problems)
  end

  desc "Find Key files table entries whose path no longer exists"
  task :paths do
    problems = markdown_files.flat_map do |file|
      documented_paths_in(file).reject { |path| File.exist?(path) }
        .map { |path| "#{file} names #{path}, which does not exist" }
    end

    report("paths", problems)
  end

  desc "Run every documentation check"
  task check: [ :coverage, :links, :paths ]

  # --- helpers ---

  def source_files
    Dir.glob("{app,lib/tasks}/**/*.{rb,erb,js,rake}").reject { |path| path.end_with?(".keep") }.sort
  end

  def markdown_files
    Dir.glob("#{DOCS_DIR}/**/*.md").reject { |path| path.end_with?("TEMPLATE.md") }.sort
  end

  # TEMPLATE.md is excluded from link checking on purpose: its relative links are
  # written for docs/features/, where a copy of it lands, not for its own location.
  def docs_corpus
    markdown_files.map { |file| File.read(file) }.join("\n") + File.read("#{DOCS_DIR}/TEMPLATE.md")
  end

  def broken_links_in(file)
    body = File.read(file)

    broken_anchors_in(file, body) + broken_relative_links_in(file, body)
  end

  def broken_anchors_in(file, body)
    headings = body.scan(/^\#{2,}\s+(.+)$/).flatten.map { |heading| slugify(heading) }

    body.scan(/\]\(\#([a-z0-9-]+)\)/).flatten.uniq
      .reject { |anchor| headings.include?(anchor) }
      .map { |anchor| "#{file} links to ##{anchor}, which is not a heading in that file" }
  end

  def broken_relative_links_in(file, body)
    body.scan(%r{\]\((?!https?:)(?!\#)([^)\#]+)(?:\#[^)]*)?\)}).flatten
      .reject { |target| File.exist?(File.expand_path(target, File.dirname(file))) }
      .map { |target| "#{file} links to #{target}, which does not exist" }
  end

  # Matches a Key files table row: | `app/some/path.rb` | description |
  def documented_paths_in(file)
    File.read(file).scan(/^\|\s*`([a-z][^`]*\.(?:rb|erb|js|yml|rake))`\s*\|/).flatten
  end

  # GitHub's heading-anchor rules: lowercase, drop punctuation, spaces to hyphens.
  def slugify(heading)
    heading.downcase.gsub(/[^a-z0-9 -]/, "").strip.tr(" ", "-")
  end

  def report(name, problems)
    if problems.empty?
      puts "docs:#{name} — ok"
      return
    end

    problems.each { |problem| puts "  #{problem}" }
    abort "docs:#{name} — #{problems.size} problem(s)"
  end
end
