bring cloud;
bring aws;
bring util;

let api = new cloud.Api(
  cors: true,
  corsOptions: cloud.ApiCorsOptions {
    allowOrigin: "*",
    allowMethods: [cloud.HttpMethod.GET, cloud.HttpMethod.POST, cloud.HttpMethod.OPTIONS],
    allowHeaders: ["Content-Type"],
    allowCredentials: false,
    exposeHeaders: ["Content-Type"],
    maxAge: 600s
  }
);

let multipartBucket = new aws.BucketRef(util.tryEnv("BUCKET_NAME") ?? "bucket-c88fdc5f-20240618085816498500000001");

let handleCompleteUpload = inflight (req: cloud.ApiRequest) => {
    let json_data = Json.parse(req.body ?? "");
    log("json_data: {json_data}");
    let s3_key = str.fromJson(json_data["s3_key"]);
    let upload_id = str.fromJson(json_data["upload_id"]);
    let parts = json_data["parts"];
    multipartBucket.completeUpload({uploadId: upload_id, key: s3_key}, unsafeCast(parts));
    return {
        "status": 200,
        "body": Json.stringify({
            "message": "video uploaded successfully"
        })
    };
};

let upload_video_in_parts = inflight (s3_key: str, mp_upload: cloud.MultipartUpload, part_no: num) => {
    let signed_url = multipartBucket.signedUrl(s3_key,    
        {
            multipartUpload: mp_upload,
            partNumber: part_no,
            action: cloud.BucketSignedUrlAction.UPLOAD
        }
    );
    log("signed url {signed_url}");
    return signed_url;
};

let handleInitiateMultipartUpload = inflight (req: cloud.ApiRequest) => {
    let json_data = Json.parse(req.body ?? "");
    let s3_key = str.fromJson(json_data["s3_key"]);
    let parts = num.fromJson(json_data["parts"]);
    log("s3_key: {s3_key}");
    log("parts: {parts}");
    let mp_upload = multipartBucket.startUpload(s3_key);
    log("mp_upload: {Json mp_upload}");
    let urls: MutArray<str> = MutArray<str>[];
    for i in 0..parts {
        let j = i +1;
        log("generating url from part {j}");
        let url = upload_video_in_parts(s3_key, mp_upload, j);
        log("url {url}");
        urls.push(url);
    }
    return {
        "status": 200,
        "body": Json.stringify({
            mp_upload: mp_upload,
            upload_urls: urls.copy()
        })
    };
};

api.post("/initiateMultipartUpload", handleInitiateMultipartUpload);
api.post("/completeUpload", handleCompleteUpload);

let website = new cloud.Website(path: "./website");
website.addJson("config.json", { apiUrl: api.url });
