-- #JericoFX... hate sumneko anotations

---@alias NewsStatus "draft"|"scheduled"|"published"|"archived"
---@alias MediaType "image"|"video"

---@class NewsMediaLink
---@field media_id number
---@field is_main boolean

---@class NewsMediaRow
---@field id number
---@field file_path string
---@field type MediaType
---@field uploaded_at string
---@field uploaded_by_cid string

---@class NewsArticleRow
---@field id number
---@field slug? string
---@field title string
---@field subtitle? string
---@field category? string
---@field status NewsStatus
---@field cover_image_url? string
---@field cover_video_url? string
---@field content_html? string
---@field content_json? string
---@field created_at string
---@field published_at? string
---@field author_cid string
---@field related_case_id? number
---@field related_incident_id? number

---@class NewsArticle
---@field id? number
---@field slug? string
---@field title string
---@field subtitle? string
---@field category? string
---@field status NewsStatus
---@field cover_image_url? string
---@field cover_video_url? string
---@field content_html? string
---@field content_json? string
---@field created_at? string
---@field published_at? string
---@field author_cid string
---@field related_case_id? number
---@field related_incident_id? number
---@field media_links NewsMediaLink[]      -- queued links to create in news_article_media
---@field media NewsMediaRow[]             -- loaded media rows (optional on Load)
local NewsArticle = lib.class('NewsArticle')

---@type table<NewsStatus, boolean>
local VALID_NEWS_STATUS = {
  draft = true,
  scheduled = true,
  published = true,
  archived = true,
}

---@private
---@param cond boolean
---@param msg string
local function assertOrError(cond, msg)
  if not cond then lib.print.error(msg) end
end

---@private
---@param s any
---@return boolean
local function isNonEmptyString(s)
  return type(s) == 'string' and #s > 0
end

---@private
---@param n any
---@return number?
local function toOptionalNumber(n)
  if n == nil then return nil end
  local v = tonumber(n)
  return v
end

---@private
---@param tableName string
---@return boolean
local function assertTableExists(tableName)
  local rows = MySQL.query.await('SHOW TABLES LIKE ?', { tableName })
  local exists = rows and #rows > 0
  if not exists then
    lib.print.error(('NewsArticle: missing required table "%s" (check sql.sql)'):format(tableName))
  end
  return exists
end

---@private
local function verifySchema()
  assertTableExists('news_articles')
  assertTableExists('news_article_media')
  assertTableExists('news_media')
end

---Create a new NewsArticle instance.
---Constructor args map 1:1 to DB columns in news_articles.
---@param id? number
---@param title string
---@param subtitle? string
---@param category? string
---@param status? NewsStatus
---@param coverImageUrl? string
---@param coverVideoUrl? string
---@param contentHtml? string
---@param contentJson? string
---@param authorCid string
---@param relatedCaseId? number
---@param relatedIncidentId? number
---@param slug? string
---@param createdAt? string
---@param publishedAt? string
function NewsArticle:constructor(
  id,
  title,
  subtitle,
  category,
  status,
  coverImageUrl,
  coverVideoUrl,
  contentHtml,
  contentJson,
  authorCid,
  relatedCaseId,
  relatedIncidentId,
  slug,
  createdAt,
  publishedAt
)
  assertOrError(isNonEmptyString(title), 'NewsArticle: "title" is required')
  assertOrError(isNonEmptyString(authorCid), 'NewsArticle: "authorCid" is required')

  status = status or 'draft'
  assertOrError(VALID_NEWS_STATUS[status] == true, ('NewsArticle: invalid "status": %s'):format(tostring(status)))

  self.id = id and tonumber(id) or nil
  self.slug = slug
  self.title = title
  self.subtitle = subtitle
  self.category = category
  self.status = status

  self.cover_image_url = coverImageUrl
  self.cover_video_url = coverVideoUrl

  self.content_html = contentHtml
  self.content_json = contentJson

  self.author_cid = authorCid
  self.related_case_id = toOptionalNumber(relatedCaseId)
  self.related_incident_id = toOptionalNumber(relatedIncidentId)

  self.created_at = createdAt
  self.published_at = publishedAt

  self.media_links = {}
  self.media = {}
end

---Attach a police case to this article (optional relationship).
---@param caseId number
---@return NewsArticle
function NewsArticle:AttachCase(caseId)
  local id = tonumber(caseId)
  assertOrError(id ~= nil, 'AttachCase: "caseId" must be a number')
  self.related_case_id = id
  return self
end

---Attach a medical incident to this article (optional relationship).
---@param incidentId number
---@return NewsArticle
function NewsArticle:AttachIncident(incidentId)
  local id = tonumber(incidentId)
  assertOrError(id ~= nil, 'AttachIncident: "incidentId" must be a number')
  self.related_incident_id = id
  return self
end

---Set rich content (HTML and optional JSON blocks).
---@param html string
---@param json? string
---@return NewsArticle
function NewsArticle:SetContent(html, json)
  assertOrError(isNonEmptyString(html), 'SetContent: "html" is required')
  self.content_html = html
  self.content_json = json
  return self
end

---Queue a media link for later persistence (requires article id on Save()).
---@param mediaId number
---@param isMain? boolean
---@return NewsArticle
function NewsArticle:LinkMedia(mediaId, isMain)
  local id = tonumber(mediaId)
  assertOrError(id ~= nil, 'LinkMedia: "mediaId" must be a number')

  ---@type NewsMediaLink
  local link = { media_id = id, is_main = isMain == true }

  local n = #self.media_links
  self.media_links[n + 1] = link
  return self
end

---Publish now (sets status and published_at on save).
---@return NewsArticle
function NewsArticle:PublishNow()
  self.status = 'published'
  return self
end

---Insert or update in DB; then persist queued media links.
---@return number articleId
function NewsArticle:Save()
  if not self.id then
    local insertId = MySQL.insert.await([[
      INSERT INTO news_articles
        (slug, title, subtitle, category, status, cover_image_url, cover_video_url, content_html, content_json,
         created_at, published_at, author_cid, related_case_id, related_incident_id)
      VALUES
        (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(),
         CASE WHEN ? = 'published' THEN NOW() ELSE NULL END,
         ?, ?, ?)
    ]], {
      self.slug,
      self.title,
      self.subtitle,
      self.category,
      self.status,
      self.cover_image_url,
      self.cover_video_url,
      self.content_html,
      self.content_json,
      self.status,
      self.author_cid,
      self.related_case_id,
      self.related_incident_id,
    })

    self.id = insertId
  else
    MySQL.update.await([[
      UPDATE news_articles
      SET slug = ?, title = ?, subtitle = ?, category = ?, status = ?,
          cover_image_url = ?, cover_video_url = ?, content_html = ?, content_json = ?,
          published_at = CASE
            WHEN ? = 'published' AND published_at IS NULL THEN NOW()
            WHEN ? <> 'published' THEN NULL
            ELSE published_at
          END,
          related_case_id = ?, related_incident_id = ?
      WHERE id = ?
    ]], {
      self.slug,
      self.title,
      self.subtitle,
      self.category,
      self.status,
      self.cover_image_url,
      self.cover_video_url,
      self.content_html,
      self.content_json,
      self.status,
      self.status,
      self.related_case_id,
      self.related_incident_id,
      self.id,
    })
  end

  -- Persist queued media links (idempotent via PK article_id+media_id)
  if self.media_links and #self.media_links > 0 then
    for i = 1, #self.media_links do
      local link = self.media_links[i]
      if link then
        MySQL.insert.await([[
          INSERT INTO news_article_media (article_id, media_id, is_main)
          VALUES (?, ?, ?)
          ON DUPLICATE KEY UPDATE is_main = VALUES(is_main)
        ]], { self.id, link.media_id, link.is_main and 1 or 0 })
      end
    end

    ---@type NewsMediaLink[]
    self.media_links = {}
  end

  return self.id
end

---Load article by id (optionally includes media rows).
---@param articleId number
---@param includeMedia? boolean
---@return NewsArticle? article
function NewsArticle.Load(articleId, includeMedia)
  local id = tonumber(articleId)
  if not id then return nil end

  ---@type NewsArticleRow[]|nil
  local rows = MySQL.query.await('SELECT * FROM news_articles WHERE id = ? LIMIT 1', { id })
  if not rows or not rows[1] then return nil end

  local r = rows[1]

  ---@type NewsArticle
  local obj = NewsArticle:new(
    r.id,
    r.title,
    r.subtitle,
    r.category,
    r.status,
    r.cover_image_url,
    r.cover_video_url,
    r.content_html,
    r.content_json,
    r.author_cid,
    r.related_case_id,
    r.related_incident_id,
    r.slug,
    r.created_at,
    r.published_at
  )

  if includeMedia == true then
    ---@type NewsMediaRow[]|nil
    local media = MySQL.query.await([[
      SELECT m.id, m.file_path, m.type, m.uploaded_at, m.uploaded_by_cid
      FROM news_article_media am
      JOIN news_media m ON m.id = am.media_id
      WHERE am.article_id = ?
      ORDER BY am.is_main DESC, m.id DESC
    ]], { id })

    obj.media = media or {}
  end

  return obj
end

verifySchema()

return NewsArticle
